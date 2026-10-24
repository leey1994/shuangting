import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/audio_cache.dart';
import '../../data/download_manager.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';
import '../widgets/lyrics_view.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  HttpServer? _server;
  bool _wasPlaying = false;

  @override
  void initState() {
    super.initState();
    _spin.repeat();
    final player = context.read<PlayerController>();
    player.addListener(_syncSpin);
  }

  void _syncSpin() {
    final playing = context.read<PlayerController>().playing;
    if (playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    context.read<PlayerController>().removeListener(_syncSpin);
    _spin.dispose();
    _server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final settings = context.watch<SettingsModel>();
    final song = player.current;
    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(title: '还没有正在播放的歌曲', subtitle: '去首页挑一首吧'),
      );
    }
    if (Platform.isWindows && settings.desktopLyric) {
      return _DesktopLyricBar(song: song);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.coverGradient(song.title.hashCode, isDark: isDark);
    final scheme = Theme.of(context).colorScheme;
    final style = settings.playerStyle;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Color.lerp(colors.first, Colors.black, 0.55)!,
                          const Color(0xFF0A0C12),
                          const Color(0xFF07080C),
                        ]
                      : [
                          Color.lerp(colors.first, Colors.white, 0.72)!,
                          const Color(0xFFF6F1E9),
                          const Color(0xFFF6F1E9),
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -160,
            right: -100,
            child: _Glow(color: colors.last, size: 380),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: _Glow(color: colors.first, size: 420),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(song: song, onMore: () => _showMore(context, song)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth > 860;
                      if (wide) {
                        return Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(40, 10, 20, 30),
                                child: style == 'lyrics'
                                    ? _CoverSide(song: song, spin: _spin, size: c.maxHeight * 0.36)
                                    : _CoverSide(song: song, spin: _spin, size: c.maxHeight * 0.62),
                              ),
                            ),
                            Expanded(
                              flex: 6,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 40, 30),
                                child: style == 'lyrics'
                                    ? Column(
                                        children: [
                                          Expanded(
                                              child: LyricsView(
                                                  expanded: true,
                                                  scale: settings.lyricScale,
                                                  glow: settings.glow)),
                                          _Controls(
                                              song: song,
                                              wide: true,
                                              onSeekStart: _onSeekStart,
                                              onSeekEnd: _onSeekEnd),
                                        ],
                                      )
                                    : _RightPanel(
                                        song: song,
                                        spin: _spin,
                                        onSeekStart: _onSeekStart,
                                        onSeekEnd: _onSeekEnd,
                                      ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          if (style == 'lyrics')
                            Expanded(
                              child: LyricsView(
                                  expanded: true,
                                  scale: settings.lyricScale,
                                  glow: settings.glow),
                            )
                          else
                            Expanded(
                              child: Center(
                                child: _CoverSide(
                                  song: song,
                                  spin: _spin,
                                  size: c.maxHeight * (style == 'minimal' ? 0.4 : 0.5),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (style != 'lyrics') ...[
                                  LyricPreview(scale: settings.lyricScale),
                                  const SizedBox(height: 4),
                                ],
                                _Controls(
                                  song: song,
                                  wide: false,
                                  onSeekStart: _onSeekStart,
                                  onSeekEnd: _onSeekEnd,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (player.error != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Material(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(player.error!,
                              style: TextStyle(color: scheme.onErrorContainer, fontSize: 12))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onSeekStart() {
    final player = context.read<PlayerController>();
    setState(() => _wasPlaying = player.playing);
    if (player.playing && context.read<SettingsModel>().dragPause) player.audio.pause();
  }

  void _onSeekEnd() {
    final player = context.read<PlayerController>();
    if (_wasPlaying) player.audio.play();
    setState(() {});
  }

  Future<void> _showMore(BuildContext context, Song song) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CoverArt(url: song.coverUrl, size: 46, radius: 12, seed: song.hash.hashCode),
              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${song.artist} · ${qualityName(context.read<PlayerController>().activeQuality)}'),
            ),
            const Divider(height: 16),
            _SheetAction(
              icon: Icons.playlist_add_rounded,
              label: '添加到歌单',
              onTap: () {
                Navigator.pop(ctx);
                showAddToPlaylist(context, song);
              },
            ),
            _SheetAction(
              icon: Icons.comment_rounded,
              label: '查看评论',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/comments', arguments: {'song': song});
              },
            ),
            _SheetAction(
              icon: Icons.info_outline_rounded,
              label: '歌曲信息',
              onTap: () {
                Navigator.pop(ctx);
                _showSongInfo(context, song);
              },
            ),
            if (Platform.isWindows)
              _SheetAction(
                icon: Icons.picture_in_picture_alt_rounded,
                label: '桌面歌词模式',
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleDesktopLyric(context);
                },
              ),
            _SheetAction(
              icon: Icons.lan_rounded,
              label: '局域网共享播放',
              onTap: () {
                Navigator.pop(ctx);
                _showLanShare(context, song);
              },
            ),
            _SheetAction(
              icon: Icons.timer_outlined,
              label: '定时关闭（30 分钟）',
              onTap: () {
                Navigator.pop(ctx);
                _sleepTimer(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleDesktopLyric(BuildContext context) async {
    final settings = context.read<SettingsModel>();
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('桌面歌词仅支持 Windows 桌面端')));
      return;
    }
    if (settings.desktopLyric) {
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSize(const Size(1280, 840));
      await windowManager.center();
      settings.desktopLyric = false;
    } else {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(const Size(960, 230));
      await windowManager.center();
      settings.desktopLyric = true;
    }
  }

  void _sleepTimer(BuildContext context) {
    Future.delayed(const Duration(minutes: 30), () {
      if (context.mounted) {
        context.read<PlayerController>().audio.pause();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('定时结束，已暂停播放')));
      }
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('将在 30 分钟后自动暂停')));
  }

  Future<void> _showSongInfo(BuildContext context, Song song) async {
    final player = context.read<PlayerController>();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('歌曲信息'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoverArt(url: song.coverUrl, size: 120, radius: 22, seed: song.hash.hashCode),
              const SizedBox(height: 16),
              _InfoRow('歌名', song.title),
              _InfoRow('歌手', song.artist),
              _InfoRow('专辑', song.album.isEmpty ? '未知' : song.album),
              _InfoRow('音质', qualityName(player.activeQuality)),
              _InfoRow('时长', formatDuration(song.duration)),
              _InfoRow('Hash', song.hash),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${song.title} - ${song.artist}'));
              Navigator.pop(ctx);
            },
            child: const Text('复制歌名'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }

  Future<void> _showLanShare(BuildContext context, Song song) async {
    final cache = context.read<AudioCache>();
    final cached = await cache.findAnyQuality(song);
    if (cached == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先播放一次，歌曲缓存后即可共享')));
      }
      return;
    }
    await _server?.close(force: true);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    server.listen((req) async {
      if (req.uri.path != '/audio') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      final file = cached.file;
      final length = await file.length();
      req.response.headers.contentType = ContentType('audio', 'mpeg');
      req.response.headers.set('Accept-Ranges', 'bytes');
      req.response.headers.set('Content-Length', '$length');
      await req.response.addStream(file.openRead());
      await req.response.close();
    });
    final ips = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    final host = ips.isEmpty || ips.first.addresses.isEmpty
        ? '127.0.0.1'
        : ips.first.addresses.first.address;
    final size = await cached.file.length();
    final url = 'http://$host:${server.port}/audio';
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('局域网共享'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('同一 Wi-Fi 下的设备可打开下面的地址播放当前歌曲：',
                style: TextStyle(fontSize: 12, height: 1.5)),
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('格式：${qualityName(cached.quality)} · ${formatBytes(size)}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('链接已复制')));
              }
            },
            child: const Text('复制链接'),
          ),
          FilledButton(
            onPressed: () async {
              await _server?.close(force: true);
              _server = null;
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('停止共享'),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Song song;
  final VoidCallback onMore;
  const _TopBar({required this.song, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                Text('正在播放',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface.withValues(alpha: 0.4))),
                const SizedBox(height: 2),
                Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(onPressed: onMore, icon: const Icon(Icons.more_horiz_rounded)),
        ],
      ),
    );
  }
}

class _CoverSide extends StatelessWidget {
  final Song song;
  final AnimationController spin;
  final double size;
  const _CoverSide({required this.song, required this.spin, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = size.clamp(160.0, 460.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: d + 34,
              height: d + 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.08), width: 1),
              ),
            ),
            RotationTransition(
              turns: spin,
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 18)),
                  ],
                ),
                child: CoverArt(
                  url: song.coverUrl,
                  size: d,
                  radius: d / 2,
                  seed: song.hash.hashCode,
                  vinyl: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(song.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: song.artistId > 0
              ? () => openArtist(context, song.artistId, song.artist)
              : null,
          child: Text(song.artist,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.55))),
        ),
      ],
    );
  }
}

class _RightPanel extends StatelessWidget {
  final Song song;
  final AnimationController spin;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  const _RightPanel({
    required this.song,
    required this.spin,
    required this.onSeekStart,
    required this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NOW PLAYING',
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w800,
                color: scheme.primary)),
        const SizedBox(height: 12),
        Text(song.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.08, letterSpacing: -1)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: song.artistId > 0 ? () => openArtist(context, song.artistId, song.artist) : null,
          child: Text(song.artist,
              style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.55))),
        ),
        const SizedBox(height: 26),
        LyricPreview(),
        const SizedBox(height: 20),
        _Controls(song: song, wide: true, onSeekStart: onSeekStart, onSeekEnd: onSeekEnd),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final Song song;
  final bool wide;
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  const _Controls({
    required this.song,
    required this.wide,
    required this.onSeekStart,
    required this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryModel>();
    final downloads = context.read<DownloadManager>();
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;
    final fav = library.isFavorite(song);
    final downloaded = library.isDownloaded(song.hash) || downloads.isActive(song.hash);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SeekBar(
          onSeekStart: onSeekStart,
          onSeekEnd: onSeekEnd,
          large: wide,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: player.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                size: 22,
                color: player.shuffle ? scheme.primary : scheme.onSurface.withValues(alpha: 0.45),
              ),
              tooltip: '随机播放',
            ),
            SizedBox(width: wide ? 26 : 8),
            IconButton(
              onPressed: player.previous,
              icon: Icon(Icons.skip_previous_rounded,
                  size: wide ? 34 : 30, color: scheme.onSurface),
            ),
            SizedBox(width: wide ? 20 : 8),
            GestureDetector(
              onTap: player.toggle,
              child: Container(
                width: wide ? 74 : 66,
                height: wide ? 74 : 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, Color.lerp(scheme.primary, Colors.black, 0.25)!],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: player.loading
                    ? const Padding(
                        padding: EdgeInsets.all(22),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                      )
                    : Icon(
                        player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: wide ? 40 : 36,
                        color: Colors.white,
                      ),
              ),
            ),
            SizedBox(width: wide ? 20 : 8),
            IconButton(
              onPressed: player.next,
              icon: Icon(Icons.skip_next_rounded,
                  size: wide ? 34 : 30, color: scheme.onSurface),
            ),
            SizedBox(width: wide ? 26 : 8),
            IconButton(
              onPressed: player.cycleLoop,
              icon: Icon(
                player.loop == PlayerLoop.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 22,
                color: player.loop == PlayerLoop.off
                    ? scheme.onSurface.withValues(alpha: 0.35)
                    : scheme.primary,
              ),
              tooltip: '循环模式',
            ),
          ],
        ),
        SizedBox(height: wide ? 18 : 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () => library.toggleFavorite(song),
              icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: fav ? scheme.primary : scheme.onSurface.withValues(alpha: 0.55)),
              tooltip: '喜欢',
            ),
            IconButton(
              onPressed: () {
                if (!downloaded) downloads.enqueue(song);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(downloaded ? '已下载或正在下载' : '已开始下载')));
              },
              icon: Icon(
                downloaded ? Icons.download_done_rounded : Icons.download_rounded,
                color: downloaded ? scheme.primary : scheme.onSurface.withValues(alpha: 0.55),
              ),
              tooltip: '下载',
            ),
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/comments', arguments: {'song': song}),
              icon: Icon(Icons.chat_bubble_outline_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.55)),
              tooltip: '评论',
            ),
            IconButton(
              onPressed: () => _showQueue(context),
              icon: Icon(Icons.queue_music_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.55)),
              tooltip: '播放队列',
            ),
            IconButton(
              onPressed: () => _showLyrics(context, settings),
              icon: Icon(Icons.lyrics_rounded,
                  color: settings.playerStyle == 'lyrics'
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.55)),
              tooltip: '歌词',
            ),
          ],
        ),
      ],
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _QueueSheet(),
    );
  }

  void _showLyrics(BuildContext context, SettingsModel settings) {
    settings.playerStyle = settings.playerStyle == 'lyrics' ? 'vinyl' : 'lyrics';
  }
}

class _SeekBar extends StatefulWidget {
  final VoidCallback onSeekStart;
  final VoidCallback onSeekEnd;
  final bool large;
  const _SeekBar({required this.onSeekStart, required this.onSeekEnd, this.large = false});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    final total = player.duration.inMilliseconds > 0
        ? player.duration.inMilliseconds
        : player.current?.duration ?? 0;
    return ValueListenableBuilder<Duration>(
      valueListenable: player.position,
      builder: (context, pos, _) {
        final current = _drag ?? pos.inMilliseconds.toDouble();
        final value = total <= 0 ? 0.0 : (current / total).clamp(0.0, 1.0);
        final buffered = total <= 0
            ? 0.0
            : (player.buffered.inMilliseconds / total).clamp(0.0, 1.0);
        return Column(
          children: [
            SizedBox(
              height: 22,
              child: LayoutBuilder(
                builder: (context, c) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        width: c.maxWidth * buffered,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: scheme.onSurface.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                      ),
                      for (final mark in player.chorusMarks)
                        Positioned(
                          left: (c.maxWidth - 2) * mark,
                          child: Container(
                            width: 3,
                            height: 11,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          activeTrackColor: scheme.primary,
                          inactiveTrackColor: Colors.transparent,
                          thumbColor: Colors.white,
                          overlayColor: scheme.primary.withValues(alpha: 0.15),
                          thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: widget.large ? 6 : 5),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
                          value: value,
                          onChangeStart: (v) {
                            widget.onSeekStart();
                            setState(() => _drag = v * total);
                          },
                          onChanged: (v) => setState(() => _drag = v * total),
                          onChangeEnd: (v) {
                            player.seek(Duration(milliseconds: (v * total).round()));
                            setState(() => _drag = null);
                            widget.onSeekEnd();
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatMs(current.round()),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: scheme.onSurface.withValues(alpha: 0.45))),
                  Text(formatMs(total),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: scheme.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
            child: Row(
              children: [
                Text('播放队列 · ${player.queue.length} 首',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (player.fmMode)
                  Chip(
                    label: const Text('私人 FM'),
                    labelStyle: const TextStyle(fontSize: 10),
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    side: BorderSide.none,
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: player.queue.length,
              itemBuilder: (_, i) {
                final s = player.queue[i];
                final active = i == player.index;
                return ListTile(
                  selected: active,
                  selectedTileColor: scheme.primary.withValues(alpha: 0.08),
                  leading: CoverArt(
                      url: s.coverUrl, size: 44, radius: 12, seed: s.hash.hashCode),
                  title: Text(s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? scheme.primary : null)),
                  subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    onPressed: () => player.removeFromQueue(i),
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: scheme.onSurface.withValues(alpha: 0.35)),
                  ),
                  onTap: () async {
                    await player.playSong(s, newQueue: player.queue, startIndex: i);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopLyricBar extends StatelessWidget {
  final Song song;
  const _DesktopLyricBar({required this.song});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF0A0C12),
            Color.lerp(scheme.primary, const Color(0xFF0A0C12), 0.75)!,
          ]),
        ),
        child: SafeArea(
          child: Row(
            children: [
              const SizedBox(width: 18),
              CoverArt(url: song.coverUrl, size: 64, radius: 16, seed: song.hash.hashCode),
              const SizedBox(width: 14),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: player.lyricIndex,
                  builder: (context, i, _) {
                    final doc = player.lyric;
                    final text = (doc == null || doc.lines.isEmpty)
                        ? song.title
                        : doc.lines[i.clamp(0, doc.lines.length - 1)].text;
                    return Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                            shadows: [
                              Shadow(color: scheme.primary.withValues(alpha: 0.5), blurRadius: 20)
                            ]));
                  },
                ),
              ),
              IconButton(
                onPressed: player.previous,
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: player.toggle,
                icon: Icon(player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: scheme.primary, size: 40),
              ),
              IconButton(
                onPressed: player.next,
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
              ),
              IconButton(
                tooltip: '退出桌面歌词',
                onPressed: () async {
                  final settings = context.read<SettingsModel>();
                  await windowManager.setAlwaysOnTop(false);
                  await windowManager.setSize(const Size(1280, 840));
                  await windowManager.center();
                  settings.desktopLyric = false;
                },
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  const _Glow({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), Colors.transparent]),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 21),
      title: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      onTap: onTap,
      dense: true,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
