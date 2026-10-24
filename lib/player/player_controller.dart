import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/audio_cache.dart';
import '../data/kg_api.dart';
import '../data/models.dart';
import '../data/store.dart';

enum PlayerLoop { off, all, one }

class PlayerController extends ChangeNotifier {
  final KgApi api;
  final AudioCache cache;
  final LibraryModel library;
  final SettingsModel settings;
  final AndroidEqualizer? equalizer = Platform.isAndroid ? AndroidEqualizer() : null;
  late final AudioPlayer audio = AudioPlayer(
    audioPipeline: equalizer == null
        ? null
        : AudioPipeline(androidAudioEffects: [equalizer!]),
  );

  PlayerController(this.api, this.cache, this.library, this.settings) {
    _init();
  }

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<int> lyricIndex = ValueNotifier(-1);

  List<Song> queue = [];
  int index = -1;
  Song? current;
  bool playing = false;
  bool loading = false;
  String? error;
  Duration duration = Duration.zero;
  Duration buffered = Duration.zero;
  PlayerLoop loop = PlayerLoop.all;
  bool shuffle = false;
  bool fmMode = false;
  String activeQuality = '';
  LyricDoc? lyric;
  List<double> chorusMarks = [];
  double volume = 1;

  Future<List<Song>> Function()? fmSource;
  bool _restored = false;
  int _restoredPositionMs = 0;
  DateTime? _playStartedAt;
  DateTime _lastSave = DateTime.now();
  bool _completedHandled = false;

  Future<void> _init() async {
    await _restoreSession();
    audio.playerStateStream.listen((state) {
      playing = state.playing;
      if (state.processingState == ProcessingState.completed) {
        if (!_completedHandled) {
          _completedHandled = true;
          _onCompleted();
        }
      } else {
        _completedHandled = false;
      }
      _safeNotify();
    });
    audio.positionStream.listen((pos) {
      position.value = pos;
      _updateLyric(pos);
      if (playing) {
        final now = DateTime.now();
        if (now.difference(_lastSave).inSeconds >= 5) {
          _lastSave = now;
          _savePosition(pos);
        }
      }
    });
    audio.durationStream.listen((d) {
      if (d != null && d > Duration.zero) {
        duration = d;
        _safeNotify();
      }
    });
    audio.bufferedPositionStream.listen((b) => buffered = b);
    audio.errorStream.listen((e) {
      error = '播放出错，正在尝试下一首';
      _safeNotify();
    });
  }

  void _safeNotify() {
    if (!hasListeners) return;
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('player_session');
      if (raw == null) return;
      final data = jsonDecodeMap(raw);
      final list = (data['queue'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final idx = (data['index'] as num?)?.toInt() ?? -1;
      if (list.isEmpty || idx < 0 || idx >= list.length) return;
      queue = list;
      index = idx;
      current = list[idx];
      duration = Duration(seconds: current!.duration);
      _restoredPositionMs = (data['position'] as num?)?.toInt() ?? 0;
      position.value = Duration(milliseconds: _restoredPositionMs);
      _restored = true;
      _safeNotify();
    } catch (_) {}
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'player_session',
          jsonEncodeMap({
            'queue': queue.map((e) => e.toJson()).toList(),
            'index': index,
            'position': position.value.inMilliseconds,
          }));
    } catch (_) {}
  }

  Future<void> _savePosition(Duration pos) async {
    if (current == null) return;
    await library.savePosition(current!.hash, pos.inMilliseconds);
    await _saveSession();
  }

  Future<void> playSong(Song song, {List<Song>? newQueue, int? startIndex}) async {
    if (newQueue != null && newQueue.isNotEmpty) {
      queue = List.of(newQueue);
      index = startIndex ?? queue.indexWhere((e) => e.hash == song.hash);
      if (index < 0) index = 0;
    } else {
      final existing = queue.indexWhere((e) => e.hash == song.hash);
      if (existing >= 0) {
        index = existing;
      } else {
        queue = [song];
        index = 0;
      }
    }
    _restored = false;
    await _load(autoPlay: true);
  }

  Future<void> _load({bool autoPlay = true, int? seekToMs}) async {
    if (index < 0 || index >= queue.length) return;
    final song = queue[index];
    current = song;
    loading = true;
    error = null;
    lyric = null;
    lyricIndex.value = -1;
    chorusMarks = [];
    duration = Duration(seconds: song.duration);
    position.value = Duration.zero;
    _safeNotify();

    try {
      CachedAudio? cached = await cache.find(song);
      String uri;
      if (song.localPath.isNotEmpty && await File(song.localPath).exists()) {
        uri = File(song.localPath).uri.toString();
        activeQuality = '本地';
      } else if (cached != null) {
        uri = cached.file.uri.toString();
        activeQuality = cached.quality;
        await cache.touch(song);
      } else {
        final resolved = await api.resolveAudio(song, settings.quality);
        uri = resolved.url;
        activeQuality = resolved.quality;
        if (settings.autoCache) {
          unawaited(cache
              .download(song, resolved.quality, urls: resolved.urls)
              .catchError((_) => File('')));
        }
      }

      await audio.setAudioSource(AudioSource.uri(
        Uri.parse(uri),
        tag: MediaItem(
          id: song.hash,
          title: song.title,
          artist: song.artist,
          album: song.album,
          artUri: song.coverUrl.isEmpty ? null : Uri.parse(song.coverUrl),
        ),
      ));
      await setSpeed(settings.speed);
      final resume = seekToMs ??
          (_restored ? _restoredPositionMs : library.positionOf(song.hash));
      if (resume > 3000) await audio.seek(Duration(milliseconds: resume));
      _restored = false;
      if (autoPlay) await audio.play();
      loading = false;
      _playStartedAt = DateTime.now();
      await library.addHistory(song);
      _loadLyrics(song);
      await _saveSession();
      _safeNotify();
    } catch (e) {
      loading = false;
      error = e is KgException ? e.message : '播放失败，请检查网络';
      _safeNotify();
    }
  }

  /// 截图/演示用：直接呈现播放状态，不依赖音频设备。
  Future<void> previewSong(Song song, {Duration at = const Duration(seconds: 52)}) async {
    current = song;
    queue = [song, ...queue.where((s) => s.hash != song.hash)];
    index = 0;
    duration = Duration(seconds: song.duration > 0 ? song.duration : 236);
    position.value = at;
    playing = true;
    loading = false;
    error = null;
    activeQuality = '320';
    lyric = await api.lyrics(song);
    _updateLyric(position.value);
    _safeNotify();
  }

  Future<void> toggle() async {
    if (current == null) return;
    if (audio.audioSource == null) {
      await _load(autoPlay: true);
      return;
    }
    if (playing) {
      await audio.pause();
      _accrueListenTime();
    } else {
      await audio.play();
      _playStartedAt = DateTime.now();
    }
  }

  Future<void> next({bool auto = false}) async {
    if (queue.isEmpty) return;
    _accrueListenTime();
    if (shuffle && queue.length > 1) {
      var n = index;
      final r = Random();
      while (n == index) {
        n = r.nextInt(queue.length);
      }
      index = n;
    } else if (index + 1 < queue.length) {
      index++;
    } else if (loop == PlayerLoop.all) {
      index = 0;
    } else if (fmMode && fmSource != null) {
      await _extendFm();
      if (index + 1 >= queue.length) return;
      index++;
    } else {
      await audio.pause();
      await audio.seek(Duration.zero);
      return;
    }
    await _load(autoPlay: true);
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (position.value.inSeconds > 4) {
      await audio.seek(Duration.zero);
      return;
    }
    _accrueListenTime();
    index = index - 1 < 0 ? queue.length - 1 : index - 1;
    await _load(autoPlay: true);
  }

  Future<void> seek(Duration d) async {
    position.value = d;
    await audio.seek(d);
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0, 1);
    await audio.setVolume(volume);
    _safeNotify();
  }

  Future<void> setSpeed(double v) async {
    try {
      await audio.setSpeed(v.clamp(0.5, 2.0));
    } catch (_) {}
  }

  Future<void> _onCompleted() async {
    _accrueListenTime();
    if (loop == PlayerLoop.one) {
      await audio.seek(Duration.zero);
      await audio.play();
      return;
    }
    await next(auto: true);
  }

  void _accrueListenTime() {
    final start = _playStartedAt;
    if (start == null) return;
    final secs = DateTime.now().difference(start).inSeconds;
    if (secs > 0) unawaited(library.addListenSeconds(secs));
    _playStartedAt = null;
  }

  void cycleLoop() {
    loop = switch (loop) {
      PlayerLoop.all => PlayerLoop.one,
      PlayerLoop.one => PlayerLoop.off,
      PlayerLoop.off => PlayerLoop.all,
    };
    _safeNotify();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _safeNotify();
  }

  Future<void> _loadLyrics(Song song) async {
    LyricDoc? doc;
    if (song.localPath.isNotEmpty) {
      try {
        final lrc = File(song.localPath.replaceFirst(RegExp(r'\.[^.]+$'), '.lrc'));
        if (await lrc.exists()) doc = LyricDoc.fromLrc(await lrc.readAsString());
      } catch (_) {}
    }
    doc ??= await api.lyrics(song);
    if (current?.hash != song.hash) return;
    lyric = doc;
    chorusMarks = _findChorus(doc);
    _updateLyric(position.value);
    _safeNotify();
  }

  List<double> _findChorus(LyricDoc? doc) {
    if (doc == null || doc.lines.length < 8 || duration.inMilliseconds <= 0) return [];
    final counts = <String, int>{};
    for (final line in doc.lines) {
      final key = line.text.trim();
      if (key.length < 2) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final repeated = counts.entries.where((e) => e.value >= 2).map((e) => e.key).toSet();
    if (repeated.isEmpty) return [];
    final marks = <double>[];
    var lastEnd = -100000.0;
    for (final line in doc.lines) {
      if (!repeated.contains(line.text.trim())) continue;
      final start = line.startMs / duration.inMilliseconds;
      if (start < 0 || start > 1) continue;
      if ((start * 100 - lastEnd).abs() < 4) continue;
      marks.add(start.clamp(0.0, 1.0));
      lastEnd = start * 100;
      if (marks.length >= 6) break;
    }
    return marks;
  }

  void _updateLyric(Duration pos) {
    final doc = lyric;
    if (doc == null || doc.lines.isEmpty) {
      if (lyricIndex.value != -1) lyricIndex.value = -1;
      return;
    }
    final ms = pos.inMilliseconds;
    var lo = 0, hi = doc.lines.length - 1, found = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (doc.lines[mid].startMs <= ms) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (found != lyricIndex.value) lyricIndex.value = found;
  }

  Future<void> enterFm(Future<List<Song>> Function() source) async {
    fmMode = true;
    fmSource = source;
    final songs = await source();
    if (songs.isEmpty) return;
    queue = List.of(songs);
    index = 0;
    await _load(autoPlay: true);
  }

  Future<void> _extendFm() async {
    final source = fmSource;
    if (source == null) return;
    final more = await source();
    final existing = queue.map((e) => e.hash).toSet();
    for (final s in more) {
      if (!existing.contains(s.hash)) queue.add(s);
    }
    _safeNotify();
  }

  void exitFm() {
    fmMode = false;
    fmSource = null;
  }

  void addToQueueNext(Song song) {
    queue.insert(index + 1, song);
    _saveSession();
    _safeNotify();
  }

  void appendToQueue(Song song) {
    queue.add(song);
    _saveSession();
    _safeNotify();
  }

  void removeFromQueue(int i) {
    if (i < 0 || i >= queue.length) return;
    queue.removeAt(i);
    if (i < index) index--;
    if (queue.isEmpty) {
      audio.stop();
      current = null;
      index = -1;
    } else if (i == index) {
      index = index.clamp(0, queue.length - 1);
      _load(autoPlay: playing);
    }
    _safeNotify();
  }

  @override
  void dispose() {
    _savePosition(position.value);
    audio.dispose();
    super.dispose();
  }
}

Map<String, dynamic> jsonDecodeMap(String raw) {
  try {
    final v = jsonDecode(raw);
    return v is Map ? Map<String, dynamic>.from(v) : {};
  } catch (_) {
    return {};
  }
}

String jsonEncodeMap(Map<String, dynamic> data) => const JsonEncoder().convert(data);
