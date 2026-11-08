import 'dart:io';
import 'dart:ui' show Color;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'settings.dart';
import 'lyric.dart';
import 'models.dart';
import 'player/player_service.dart';

class MusicAudioHandler extends BaseAudioHandler {
  MusicAudioHandler() {
    PlayerService.instance.pageListenable.addListener(_sync);
    PlayerService.instance.progressListenable.addListener(_sync);
    _sync();
  }

  bool? _lastPlaying;
  String? _lastMediaId;
  String? _lastError;
  AudioProcessingState? _lastProcessing;
  int? _lastQueueLength;
  int? _lastQueueVersion;
  String? _lastLyricLine;
  DateTime _lastSyncAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _sync() {
    final player = PlayerService.instance;
    final song = player.current;
    final isPlaying = player.playing;
    final processing = player.loading
        ? AudioProcessingState.loading
        : song == null
            ? AudioProcessingState.idle
            : player.lastError == null
                ? AudioProcessingState.ready
                : AudioProcessingState.error;

    final now = DateTime.now();
    final mediaId = song?.key;
    final lyricLine = Settings.instance.get<bool>('bluetoothLyric') ? _lyricAt(player) : null;
    final queueChanged = _lastQueueVersion != player.queueVersion;
    final changed = _lastPlaying != isPlaying ||
        _lastMediaId != mediaId ||
        _lastError != player.lastError ||
        _lastProcessing != processing ||
        _lastQueueLength != player.queue.length ||
        queueChanged ||
        _lastLyricLine != lyricLine;
    if (!changed && now.difference(_lastSyncAt) < const Duration(seconds: 2)) return;
    _lastSyncAt = now;
    _lastPlaying = isPlaying;
    _lastMediaId = mediaId;
    _lastError = player.lastError;
    _lastProcessing = processing;
    _lastQueueLength = player.queue.length;
    _lastQueueVersion = player.queueVersion;
    _lastLyricLine = lyricLine;

    if (song != null) {
      mediaItem.add(_mediaItem(song, lyricLine: lyricLine));
    } else {
      mediaItem.add(null);
    }
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processing,
      playing: isPlaying,
      updatePosition: player.position,
      bufferedPosition: player.position,
      speed: player.speed,
      queueIndex: player.index < 0 ? null : player.index,
    ));
    if (queueChanged) {
      queue.add(player.queue.map(_mediaItem).toList());
    }
  }

  String? _lyricAt(PlayerService player) {
    final doc = player.lyric;
    if (doc == null || doc.isEmpty) return null;
    final i = lyricIndexAt(doc.lines, player.position);
    if (i < 0) return null;
    final text = doc.lines[i].text.trim();
    return text.isEmpty ? null : text;
  }

  MediaItem _mediaItem(MusicItem song, {String? lyricLine}) {
    Uri? artUri;
    if (song.artwork.startsWith('http://') || song.artwork.startsWith('https://')) {
      artUri = Uri.tryParse(song.artwork);
    } else if (song.artwork.isNotEmpty && File(song.artwork).existsSync()) {
      artUri = Uri.file(song.artwork);
    }
    return MediaItem(
      id: song.key,
      title: song.title.isEmpty ? '未知曲目' : song.title,
      artist: song.displayArtist,
      album: lyricLine ?? song.album,
      artUri: artUri,
      duration: song.duration > 0 ? Duration(seconds: song.duration) : null,
      extras: _safeExtras(song.toJson()),
    );
  }

  Map<String, dynamic> _safeExtras(Map<String, dynamic> raw) => raw.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );

  @override
  Future<void> play() => PlayerService.instance.toggle();

  @override
  Future<void> pause() => PlayerService.instance.pause();

  @override
  Future<void> stop() async {
    await PlayerService.instance.pause();
    await super.stop();
  }

  @override
  Future<void> skipToNext() => PlayerService.instance.next();

  @override
  Future<void> skipToPrevious() => PlayerService.instance.previous();

  @override
  Future<void> seek(Duration position) => PlayerService.instance.seek(position);

  @override
  Future<void> skipToQueueItem(int index) => PlayerService.instance.playAt(index);
}

Future<MusicAudioHandler> initMusicAudioService() async {
  if (kIsWeb) throw UnsupportedError('Background audio is unavailable on web');
  return AudioService.init(
    builder: MusicAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kugou.android.audio',
      androidNotificationChannelName: '爽听音乐播放',
      androidNotificationChannelDescription: '正在播放的歌曲与播放控制',
      androidNotificationIcon: 'drawable/ic_stat_music',
      notificationColor: Color(0xFFFF6B5B),
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      artDownscaleWidth: 256,
      artDownscaleHeight: 256,
    ),
  );
}
