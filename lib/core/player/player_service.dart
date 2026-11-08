import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../library_store.dart';
import '../lyric.dart';
import '../media_cache.dart';
import '../models.dart';
import '../plugin/plugin_manager.dart';
import '../settings.dart';
import 'media_proxy.dart';

enum PlayMode { sequence, repeatAll, repeatOne, shuffle }

extension PlayModeX on PlayMode {
  String get label => const ['顺序播放', '列表循环', '单曲循环', '随机播放'][index];
}

class PlayerService extends ChangeNotifier {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  List<MusicItem> queue = [];
  int queueVersion = 0;
  int index = -1;
  PlayMode mode = PlayMode.sequence;

  bool playing = false;
  bool loading = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double speed = 1.0;
  String? lastError;

  LyricDoc? lyric;
  bool lyricLoading = false;
  int _lyricRequest = 0;

  Timer? _sleepTimer;
  DateTime? _sleepDeadline;

  List<int> _shuffleOrder = [];

  MusicItem? get current => (index >= 0 && index < queue.length) ? queue[index] : null;
  String? get currentKey => current?.key;

  Duration? get sleepRemaining {
    final d = _sleepDeadline;
    if (d == null) return null;
    final left = d.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setAudioContext(AudioContextConfig(stayAwake: true).build());
    _player.onPositionChanged.listen((pos) {
      position = pos;
      // 进度回调约 200ms 一次，节流到 500ms，避免整页高频重建。
      final now = DateTime.now();
      if (now.difference(_lastPositionNotify) < const Duration(milliseconds: 500)) return;
      _lastPositionNotify = now;
      _notifyProgress();
    });
    _player.onDurationChanged.listen((d) {
      duration = d;
      final restore = _positionToRestore;
      if (restore != null && restore > Duration.zero && d > restore) {
        _positionToRestore = null;
        _player.seek(restore);
      }
      _notifyPage();
    });
    _player.onPlayerStateChanged.listen((state) {
      playing = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        _onCompleted();
      }
      _notifyPage();
    });
    _player.onPlayerComplete.listen((_) => _onCompleted());
    _player.onLog.listen((msg) {
      if (kDebugMode) debugPrint('[player] $msg');
    });

    await restoreState(PrefStore.instance.getJson(_prefsState));
    if (queue.isNotEmpty && index >= 0 && Settings.instance.get<bool>('autoPlayOnStart')) {
      await playAt(index);
    }
  }

  static const _prefsState = 'playerState';
  final ChangeNotifier _pageNotifier = ChangeNotifier();
  final ChangeNotifier _progressNotifier = ChangeNotifier();
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  Duration? _positionToRestore;
  DateTime _lastPositionNotify = DateTime.fromMillisecondsSinceEpoch(0);

  Listenable get pageListenable => _pageNotifier;
  Listenable get progressListenable => _progressNotifier;

  void _persistThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastPersist) <= const Duration(seconds: 2)) return;
    _lastPersist = now;
    try {
      PrefStore.instance.setJson(_prefsState, exportState());
    } catch (_) {}
  }

  void _notifyPage() {
    _persistThrottled();
    _pageNotifier.notifyListeners();
    _progressNotifier.notifyListeners();
    notifyListeners();
  }

  void _notifyProgress() {
    _persistThrottled();
    _progressNotifier.notifyListeners();
  }

  bool _completionHandled = false;

  Future<void> _onCompleted() async {
    if (_completionHandled) return;
    _completionHandled = true;
    Future.delayed(const Duration(milliseconds: 300), () => _completionHandled = false);
    if (mode == PlayMode.repeatOne) {
      await seek(Duration.zero);
      await _player.resume();
    } else {
      await next(auto: true);
    }
  }

  // ---------------- 播放控制 ----------------

  Future<void> playQueue(List<MusicItem> songs,
      {int startIndex = 0, bool autoPlay = true}) async {
    if (songs.isEmpty) return;
    queue = List<MusicItem>.from(songs);
    index = startIndex.clamp(0, queue.length - 1);
    queueVersion++;
    _rebuildShuffle();
    if (autoPlay) {
      await playAt(index);
    } else {
      _notifyPage();
    }
  }

  Future<void> playNow(MusicItem song, {List<MusicItem>? context}) async {
    final list = context ?? [song];
    final i = list.indexWhere((e) => e.key == song.key);
    await playQueue(list, startIndex: i < 0 ? 0 : i);
  }

  Future<void> playAt(int i) async {
    if (i < 0 || i >= queue.length) return;
    index = i;
    final song = queue[i];
    loading = true;
    lastError = null;
    position = Duration.zero;
    duration = Duration.zero;
    lyric = null;
    _notifyPage();

    LibraryStore.instance.addHistory(song);
    _loadLyric(song);

    try {
      final resolved = await _resolve(song);
      if (resolved == null) {
        lastError = '无法获取播放地址';
        loading = false;
        _notifyPage();
        if (Settings.instance.get<bool>('autoStopWhenError') == false) {
          // 保持当前曲目，等待用户重试
        }
        return;
      }
      await _player.stop();
      await _player.setSourceUrl(resolved);
      await _player.setPlaybackRate(speed);
      await _player.resume();
      playing = true;
      _restorePositionIfNeeded(song, resolved);
    } catch (e) {
      lastError = '播放失败：$e';
      debugPrint('[player] $e');
      if (!Settings.instance.get<bool>('autoStopWhenError')) {
        // 交给用户处理
      }
    } finally {
      loading = false;
      _notifyPage();
    }
  }
  int _restorePositionGeneration = 0;

  Future<void> _restorePositionIfNeeded(MusicItem song, String source) async {
    final expected = position;
    if (expected <= Duration.zero || expected >= duration) return;
    final token = ++_restorePositionGeneration;
    try {
      // Source load may publish duration/position asynchronously; seek only when ready.
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (token != _restorePositionGeneration || currentKey != song.key || !playing) return;
        if (duration > Duration.zero) {
          await _player.seek(expected);
          return;
        }
      }
    } catch (_) {}
  }

  Future<String?> _resolve(MusicItem song) async {
    // 本地文件
    final local = song.localPath ?? MediaCache.instance.localPath(song.key);
    if (local != null && local.isNotEmpty) {
      final f = File(local);
      if (await f.exists()) return local;
    }

    final quality = Settings.instance.get<String>('defaultQuality');
    var record = PluginManager.instance.byPlatform(song.platform);
    if (record != null && record.enabled) {
      final info = await PluginManager.instance.getMediaSource(record, song, quality: quality);
      if (info?.url != null && info!.url!.isNotEmpty) {
        await MediaProxy.instance.ensureStarted();
        return MediaProxy.instance.register(info.url!, info.headers, userAgent: info.userAgent);
      }
    }

    // 自动换源
    if (Settings.instance.get<bool>('tryChangeSource')) {
      final alt = await _findAlternative(song, excludePlatform: song.platform);
      if (alt != null) return alt;
    }
    return null;
  }

  Future<String?> _findAlternative(MusicItem song, {String? excludePlatform}) async {
    final plugins = PluginManager.instance.enabled
        .where((e) => e.platform != excludePlatform && e.methods.contains('search'))
        .take(3);
    for (final plugin in plugins) {
      try {
        final res = await PluginManager.instance.search(plugin, '${song.title} ${song.artist}'.trim(), 1, 'music');
        if (res == null) continue;
        for (final raw in res.data.whereType<Map>()) {
          final candidate = MusicItem.fromJson(Map<String, dynamic>.from(raw));
          if (candidate.title.trim() != song.title.trim()) continue;
          final info = await PluginManager.instance.getMediaSource(plugin, candidate,
              quality: Settings.instance.get<String>('defaultQuality'));
          if (info?.url != null && info!.url!.isNotEmpty) {
            await MediaProxy.instance.ensureStarted();
            return MediaProxy.instance.register(info.url!, info.headers, userAgent: info.userAgent);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> toggle() async {
    if (current == null) return;
    if (playing) {
      await _player.pause();
    } else {
      if (_player.state == PlayerState.paused) {
        await _player.resume();
      } else {
        await playAt(index);
      }
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> resume() => _player.resume();

  Future<void> seek(Duration d) async {
    position = d;
    _notifyProgress();
    await _player.seek(d);
  }

  Future<void> seekToRatio(double ratio) async {
    if (duration.inMilliseconds <= 0) return;
    await seek(Duration(milliseconds: (duration.inMilliseconds * ratio).round()));
  }

  Future<void> setSpeed(double value) async {
    speed = value.clamp(0.5, 2.0);
    await _player.setPlaybackRate(speed);
    await Settings.instance.set('playSpeed', speed);
    _notifyPage();
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    if (mode == PlayMode.repeatOne && auto) {
      await seek(Duration.zero);
      await _player.resume();
      return;
    }
    if (mode == PlayMode.shuffle) {
      if (_shuffleOrder.length != queue.length) _rebuildShuffle();
      final pos = _shuffleOrder.indexOf(index);
      if (pos >= 0 && pos + 1 < _shuffleOrder.length) {
        await playAt(_shuffleOrder[pos + 1]);
        return;
      }
      if (mode == PlayMode.shuffle) _rebuildShuffle(currentFirst: true);
      if (_shuffleOrder.isNotEmpty) {
        await playAt(_shuffleOrder.first);
        return;
      }
    }
    var nextIndex = index + 1;
    if (nextIndex >= queue.length) {
      if (mode == PlayMode.repeatAll) {
        nextIndex = 0;
      } else if (auto) {
        await _player.pause();
        playing = false;
        _notifyPage();
        return;
      } else {
        nextIndex = 0;
      }
    }
    await playAt(nextIndex);
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (position.inSeconds > 4) {
      await seek(Duration.zero);
      return;
    }
    if (mode == PlayMode.shuffle) {
      if (_shuffleOrder.length != queue.length) _rebuildShuffle();
      final pos = _shuffleOrder.indexOf(index);
      if (pos > 0) {
        await playAt(_shuffleOrder[pos - 1]);
        return;
      }
    }
    var prev = index - 1;
    if (prev < 0) prev = mode == PlayMode.repeatAll ? queue.length - 1 : 0;
    await playAt(prev);
  }

  void _rebuildShuffle({bool currentFirst = false}) {
    final indices = List<int>.generate(queue.length, (i) => i);
    if (currentFirst && index >= 0) {
      indices.remove(index);
      indices.shuffle(_random);
      _shuffleOrder = [index, ...indices];
    } else {
      indices.shuffle(_random);
      _shuffleOrder = indices;
    }
  }

  Future<void> cycleMode() async {
    final values = PlayMode.values;
    mode = values[(mode.index + 1) % values.length];
    if (mode == PlayMode.shuffle) _rebuildShuffle();
    _notifyPage();
  }

  Future<void> setMode(PlayMode m) async {
    mode = m;
    if (m == PlayMode.shuffle) _rebuildShuffle();
    _notifyPage();
  }

  // ---------------- 队列编辑 ----------------

  Future<void> playNext(MusicItem song) async {
    final existing = queue.indexWhere((e) => e.key == song.key);
    if (existing >= 0) {
      queue.removeAt(existing);
      if (existing <= index) index--;
    }
    queue.insert((index + 1).clamp(0, queue.length), song);
    queueVersion++;
    _rebuildShuffle();
    _notifyPage();
  }

  Future<void> addToQueue(MusicItem song) async {
    if (queue.any((e) => e.key == song.key)) return;
    queue.add(song);
    queueVersion++;
    _rebuildShuffle();
    _notifyPage();
  }

  Future<void> removeAt(int i) async {
    if (i < 0 || i >= queue.length) return;
    final wasCurrent = i == index;
    queue.removeAt(i);
    if (queue.isEmpty) {
      index = -1;
      await _player.stop();
    } else if (i < index) {
      index--;
    } else if (wasCurrent) {
      index = index.clamp(0, queue.length - 1);
      await playAt(index);
    }
    queueVersion++;
    _rebuildShuffle();
    _notifyPage();
  }

  Future<void> moveQueue(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = queue.removeAt(oldIndex);
    queue.insert(newIndex, item);
    if (index == oldIndex) {
      index = newIndex;
    } else if (oldIndex < index && newIndex >= index) {
      index--;
    } else if (oldIndex > index && newIndex <= index) {
      index++;
    }
    queueVersion++;
    _rebuildShuffle();
    _notifyPage();
  }

  Future<void> clearQueue() async {
    queue.clear();
    queueVersion++;
    index = -1;
    lyric = null;
    await _player.stop();
    _notifyPage();
  }

  // ---------------- 歌词 ----------------

  Future<void> _loadLyric(MusicItem song) async {
    final request = ++_lyricRequest;
    lyricLoading = true;
    lyric = null;
    _notifyPage();

    final targetKey = MediaCache.instance.resolveLyricTarget(song.key);
    final target = targetKey == song.key ? song : (MediaCache.instance.associatedItem(targetKey) ?? song);

    String? raw = MediaCache.instance.localLyric(targetKey) ?? MediaCache.instance.cachedLyric(targetKey);

    if (raw == null || raw.isEmpty) {
      // 本地文件同名 .lrc
      final local = target.localPath ?? MediaCache.instance.localPath(target.key);
      if (local != null && local.isNotEmpty) {
        final lrcFile = File(p.setExtension(local, '.lrc'));
        if (await lrcFile.exists()) {
          try {
            raw = await lrcFile.readAsString();
          } catch (_) {}
        }
      }
    }

    if (raw == null || raw.isEmpty) {
      final record = PluginManager.instance.byPlatform(target.platform);
      if (record != null && record.enabled) {
        final src = await PluginManager.instance.getLyric(record, target);
        if (src != null) raw = src.text;
      }
    }

    if (raw == null || raw.isEmpty) {
      try {
        raw = await PluginManager.instance
            .autoMatchLyric(target)
            .timeout(const Duration(seconds: 20));
      } catch (_) {}
    }

    if (request != _lyricRequest) return;
    if (raw != null && raw.isNotEmpty) {
      await MediaCache.instance.setCachedLyric(targetKey, raw);
      lyric = parseLyric(raw);
    } else {
      lyric = null;
    }
    lyricLoading = false;
    _notifyPage();
  }

  Future<void> reloadLyric() async {
    final song = current;
    if (song != null) await _loadLyric(song);
  }

  // ---------------- 定时关闭 ----------------

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDeadline = null;
    if (duration != null) {
      _sleepDeadline = DateTime.now().add(duration);
      _sleepTimer = Timer(duration, () {
        pause();
        _sleepTimer = null;
        _sleepDeadline = null;
        _notifyPage();
      });
    }
    _notifyPage();
  }

  Map<String, dynamic> exportState() => {
        'queue': queue.map((e) => e.toJson()).toList(),
        'index': index,
        'mode': mode.index,
        'speed': speed,
        'position': position.inMilliseconds,
      };

  Future<void> restoreState(Map<String, dynamic> state) async {
    try {
      final list = (state['queue'] as List?) ?? [];
      queue = list.whereType<Map>().map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e))).toList();
      queueVersion++;
      index = (state['index'] as num?)?.toInt() ?? -1;
      if (index >= queue.length) index = queue.length - 1;
      mode = PlayMode.values[(state['mode'] as num?)?.toInt().clamp(0, 3) ?? 0];
      speed = ((state['speed'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 2.0);
      position = Duration(milliseconds: (state['position'] as num?)?.toInt() ?? 0);
      _positionToRestore = position;
      _rebuildShuffle();
    } catch (_) {}
    _notifyPage();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _pageNotifier.dispose();
    _progressNotifier.dispose();
    _player.dispose();
    super.dispose();
  }
}
