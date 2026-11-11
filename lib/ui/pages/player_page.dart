import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/library_store.dart';
import '../../core/lyric.dart';
import '../../core/media_cache.dart';
import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';
import 'queue_page.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with SingleTickerProviderStateMixin {
  bool _showLyric = false;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 28))
    ..repeat();

  @override
  void initState() {
    super.initState();
    PlayerService.instance.pageListenable.addListener(_syncSpin);
    _syncSpin();
  }

  void _syncSpin() {
    final playing = PlayerService.instance.playing;
    if (playing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!playing && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    PlayerService.instance.pageListenable.removeListener(_syncSpin);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PlayerService.instance.pageListenable,
      builder: (context, _) {
        final p = PlayerService.instance;
        final song = p.current;
        if (song == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(),
            body: const EmptyView(text: '还没有正在播放的歌曲', icon: Icons.music_note_rounded),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              _Backdrop(artwork: song.artwork),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 700 && constraints.maxWidth > constraints.maxHeight;
                    final cover = _CoverView(artwork: song.artwork, spin: _spin, availableSize: Size(constraints.maxWidth, constraints.maxHeight));
                    if (!wide) {
                      return Column(
                        children: [
                          _TopBar(
                            song: song,
                            showLyric: _showLyric,
                            onToggleLyric: () => setState(() => _showLyric = !_showLyric),
                          ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 360),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: _showLyric
                                  ? _LyricView(key: const ValueKey('lyric'), doc: p.lyric, loading: p.lyricLoading)
                                  : GestureDetector(key: const ValueKey('cover'), onTap: () => setState(() => _showLyric = !_showLyric), child: cover),
                            ),
                          ),
                          _InfoRow(song: song),
                          const _SeekBar(),
                          _Controls(showLyric: _showLyric, onToggleLyric: () => setState(() => _showLyric = !_showLyric)),
                          const SizedBox(height: 12),
                        ],
                      );
                    }
                    // 车机/横屏：左侧固定封面，右侧歌词和状态，底部共享进度与控制。
                    return Column(
                      children: [
                        _TopBar(
                          song: song,
                          showLyric: false,
                          onToggleLyric: () => setState(() => _showLyric = !_showLyric),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Center(
                                    child: _CoverView(
                                      artwork: song.artwork,
                                      spin: _spin,
                                      availableSize: Size(constraints.maxWidth * 0.45, constraints.maxHeight - 90),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 26),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    children: [
                                      _InfoRow(song: song),
                                      const SizedBox(height: 10),
                                      Expanded(child: _LyricView(doc: p.lyric, loading: p.lyricLoading)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const _SeekBar(),
                        _Controls(showLyric: true, onToggleLyric: () {}),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.artwork});
  final String artwork;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (artwork.startsWith('http')) {
      image = Image.network(artwork, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox());
    } else if (artwork.isNotEmpty) {
      image = Image.file(File(artwork), fit: BoxFit.cover, cacheWidth: 480, errorBuilder: (_, _, _) => const SizedBox());
    } else {
      image = const SizedBox();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).colorScheme.surface),
        Opacity(
          opacity: Theme.of(context).brightness == Brightness.dark ? 0.42 : 0.28,
          child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: image),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white).withValues(alpha: 0.15),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.song, required this.showLyric, required this.onToggleLyric});
  final MusicItem song;
  final bool showLyric;
  final VoidCallback onToggleLyric;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          ),
          Expanded(
            child: Column(
              children: [
                Text(t('正在播放'), style: TextStyle(fontSize: 11, letterSpacing: 3, color: AppPalette.muted(context))),
                const SizedBox(height: 2),
                Text(
                  song.platform == 'local' ? t('本地音乐') : '${t('来自')} ${song.platform}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggleLyric,
            icon: Icon(showLyric ? Icons.album_rounded : Icons.lyrics_rounded, size: 22),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QueuePage())),
            icon: const Icon(Icons.queue_music_rounded, size: 24),
          ),
        ],
      ),
    );
  }
}

class _CoverView extends StatelessWidget {
  const _CoverView({required this.artwork, required this.spin, this.availableSize});
  final String artwork;
  final Animation<double> spin;
  final Size? availableSize;

  @override
  Widget build(BuildContext context) {
    final available = availableSize ?? MediaQuery.sizeOf(context);
    final size = math.min(math.min(available.width * 0.72, available.height - 36), 320.0).clamp(110.0, 320.0);
    return Center(
      child: AnimatedBuilder(
        animation: spin,
        builder: (context, _) {
          return Transform.rotate(
            angle: spin.value * math.pi * 2,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14161C), // 黑胶本体保持深色，两种主题下都是唱片质感
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                    blurRadius: 60,
                    spreadRadius: 4,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 唱片纹路
                  for (var i = 0; i < 7; i++)
                    Container(
                      width: size - i * 26,
                      height: size - i * 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.035), width: 1),
                      ),
                    ),
                  ClipOval(
                    child: SizedBox(
                      width: size * 0.66,
                      height: size * 0.66,
                      child: CoverImage(path: artwork, size: size * 0.66, radius: size),
                    ),
                  ),
                  Container(
                    width: size * 0.12,
                    height: size * 0.12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B0D11),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LyricView extends StatefulWidget {
  const _LyricView({super.key, required this.doc, required this.loading});
  final LyricDoc? doc;
  final bool loading;

  @override
  State<_LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<_LyricView> {
  final ScrollController _controller = ScrollController();
  int _lastIndex = -1;
  double _lastUserScroll = 0;
  static const _lineHeight = 52.0;

  @override
  void initState() {
    super.initState();
    PlayerService.instance.progressListenable.addListener(_onTick);
    PlayerService.instance.pageListenable.addListener(_onTick);
    _scrollToCurrent();
  }

  void _onTick() => _scrollToCurrent();

  void _scrollToCurrent() {
    final doc = widget.doc;
    if (doc == null || doc.lines.isEmpty || !doc.synced) return;
    final idx = lyricIndexAt(doc.lines, _position());
    if (idx == _lastIndex) return;
    _lastIndex = idx;
    if (DateTime.now().millisecondsSinceEpoch / 1000 - _lastUserScroll < 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final maxScroll = _controller.position.hasContentDimensions ? _controller.position.maxScrollExtent : 0.0;
      final target = (idx * _lineHeight).clamp(0.0, maxScroll);
      _controller.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    });
  }

  Duration _position() {
    final p = PlayerService.instance;
    final key = p.currentKey ?? '';
    return p.position + Duration(milliseconds: (MediaCache.instance.lyricOffset(key) * 1000).round());
  }

  @override
  void didUpdateWidget(covariant _LyricView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc != widget.doc || oldWidget.loading != widget.loading) {
      _lastIndex = -1;
      _scrollToCurrent();
    }
  }

  @override
  void dispose() {
    PlayerService.instance.progressListenable.removeListener(_onTick);
    PlayerService.instance.pageListenable.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    if (widget.loading) return const LoadingView(text: '正在获取歌词');
    if (doc == null || doc.isEmpty) {
      return EmptyView(
        icon: Icons.lyrics_outlined,
        text: '暂无歌词\n可以去歌曲菜单里搜索或粘贴歌词',
        action: () async {
          final p = PlayerService.instance.current;
          if (p == null) return;
          await showSongActions(context, p);
        },
        actionLabel: '关联歌词',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is UserScrollNotification) {
          _lastUserScroll = DateTime.now().millisecondsSinceEpoch / 1000;
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = math.max(12.0, (constraints.maxHeight - _lineHeight) / 2);
          return ListenableBuilder(
            listenable: PlayerService.instance.progressListenable,
            builder: (context, _) {
              final idx = lyricIndexAt(doc.lines, _position());
              return ListView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: pad, horizontal: 16),
                itemExtent: _lineHeight,
                itemCount: doc.lines.length,
                itemBuilder: (context, i) {
                  final line = doc.lines[i];
                  final active = i == idx;
                  final sung = i < idx;
                  final fontSize = MediaQuery.textScalerOf(context).scale(active ? 19 : 14.5);
                  return GestureDetector(
                    onTap: () {
                      if (!doc.synced) return;
                      PlayerService.instance.seek(line.time - Duration(milliseconds: (MediaCache.instance.lyricOffset(PlayerService.instance.currentKey ?? '') * 1000).round()));
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: fontSize,
                          height: 1.2,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : (sung ? AppPalette.muted(context).withValues(alpha: 0.48) : AppPalette.muted(context)),
                        ),
                        textAlign: TextAlign.center,
                        child: Text(line.text.isEmpty ? '· · ·' : line.text, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.song});
  final MusicItem song;

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    final isFav = lib.isFavorite(song);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Text(song.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: AppPalette.muted(context))),
              ],
            ),
          ),
          IconButton(
            onPressed: () => lib.toggleFavorite(song),
            icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFav ? Theme.of(context).colorScheme.primary : null),
          ),
          IconButton(
            onPressed: () => showSongActions(context, song),
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    PlayerService.instance.progressListenable.addListener(_onTick);
    PlayerService.instance.pageListenable.addListener(_onTick);
  }

  void _onTick() { if (mounted) setState(() {}); }

  @override
  void dispose() {
    PlayerService.instance.progressListenable.removeListener(_onTick);
    PlayerService.instance.pageListenable.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = PlayerService.instance.duration;
    final total = duration.inMilliseconds;
    // 时长未知时不要按进度 100% 画满整条，否则一开始就是"播放完"的样子。
    final value = total <= 0
        ? 0.0
        : (_dragValue ?? PlayerService.instance.position.inMilliseconds / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value.toDouble(),
              onChanged: (v) => setState(() => _dragValue = v),
              onChangeEnd: (v) {
                PlayerService.instance.seekToRatio(v);
                setState(() => _dragValue = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(_fmt(PlayerService.instance.position), style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                const Spacer(),
                Text(_fmt(PlayerService.instance.duration), style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  const _Controls({required this.showLyric, required this.onToggleLyric});
  final bool showLyric;
  final VoidCallback onToggleLyric;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _speedBoostActive = false;
  double _normalSpeed = 1.0;

  Future<void> _beginTemporarySpeed() async {
    if (_speedBoostActive) return;
    final p = PlayerService.instance;
    setState(() {
      _normalSpeed = p.speed;
      _speedBoostActive = true;
    });
    await p.setSpeed(2.0);
  }

  Future<void> _endTemporarySpeed() async {
    if (!_speedBoostActive) return;
    setState(() => _speedBoostActive = false);
    await PlayerService.instance.setSpeed(_normalSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.instance;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: p.cycleMode,
                icon: Icon(_modeIcon(p.mode), size: 22, color: AppPalette.muted(context)),
                tooltip: t(p.mode.label),
              ),
              IconButton(
                onPressed: p.previous,
                icon: const Icon(Icons.skip_previous_rounded, size: 38),
              ),
              GestureDetector(
                onTap: p.toggle,
                onLongPressStart: (_) => _beginTemporarySpeed(),
                onLongPressEnd: (_) => _endTemporarySpeed(),
                onLongPressCancel: _endTemporarySpeed,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppPalette.brandGradient(context),
                    boxShadow: [
                      BoxShadow(color: primary.withValues(alpha: 0.34), blurRadius: 26, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_speedBoostActive)
                        const Positioned(top: 6, child: Text('2x', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))
                      else if (p.loading)
                        const Padding(padding: EdgeInsets.all(22), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      else
                        Icon(p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: p.next,
                icon: const Icon(Icons.skip_next_rounded, size: 38),
              ),
              IconButton(
                onPressed: () => _showSpeed(context),
                icon: const Icon(Icons.speed_rounded, size: 22, color: null),
                tooltip: t('播放速度'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _showSleepTimer(context),
                icon: const Icon(Icons.bedtime_outlined, size: 18),
                label: Text(
                  p.sleepRemaining == null ? t('定时关闭') : _fmtLeft(p.sleepRemaining!),
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(foregroundColor: AppPalette.muted(context)),
              ),
              TextButton.icon(
                onPressed: widget.onToggleLyric,
                icon: Icon(widget.showLyric ? Icons.album_outlined : Icons.lyrics_outlined, size: 18),
                label: Text(widget.showLyric ? t('封面') : t('歌词'), style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppPalette.muted(context)),
              ),
              TextButton.icon(
                onPressed: () => _showLyricOffset(context),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text('${t('歌词偏移')} ${MediaCache.instance.lyricOffset(p.currentKey ?? '').toStringAsFixed(1)}s', style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppPalette.muted(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtLeft(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return Icons.playlist_play_rounded;
      case PlayMode.repeatAll:
        return Icons.repeat_on_rounded;
      case PlayMode.repeatOne:
        return Icons.repeat_one_rounded;
      case PlayMode.shuffle:
        return Icons.shuffle_rounded;
    }
  }

  Future<void> _showSpeed(BuildContext context) async {
    final p = PlayerService.instance;
    final value = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.only(bottom: 8), child: Tr('播放速度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            for (final s in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                title: Text('${s}x'),
                trailing: (p.speed - s).abs() < 0.01 ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (value != null) await p.setSpeed(value);
  }

  Future<void> _showSleepTimer(BuildContext context) async {
    final p = PlayerService.instance;
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(padding: EdgeInsets.only(bottom: 8), child: Tr('定时关闭', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            for (final minutes in [15, 30, 60, 90, 120])
              ListTile(
                title: Text('$minutes 分钟'),
                onTap: () => Navigator.pop(context, minutes),
              ),
            ListTile(
              title: const Text('关闭定时'),
              onTap: () => Navigator.pop(context, 0),
            ),
          ],
        ),
      ),
    );
    if (choice != null) {
      p.setSleepTimer(choice == 0 ? null : Duration(minutes: choice));
    }
  }

  Future<void> _showLyricOffset(BuildContext context) async {
    final key = PlayerService.instance.currentKey;
    if (key == null) return;
    double current = MediaCache.instance.lyricOffset(key);
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('歌词偏移'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${current.toStringAsFixed(1)} 秒', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(onPressed: () { setState(() => current -= 0.5); }, child: const Text('-0.5')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: () { setState(() => current += 0.5); }, child: const Text('+0.5')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Tr('取消')),
            FilledButton(
              onPressed: () async {
                await MediaCache.instance.setLyricOffset(key, current);
                if (context.mounted) Navigator.pop(context);
                await PlayerService.instance.reloadLyric();
              },
              child: const Tr('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
