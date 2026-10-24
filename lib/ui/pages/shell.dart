import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';
import 'car_page.dart';
import 'charts_page.dart';
import 'discover_page.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'profile_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

/// 供调试扩展切换底部标签页。
final ValueNotifier<int> shellTab = ValueNotifier<int>(0);

class _ShellState extends State<Shell> {
  int _index = shellTab.value;

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTab);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() => _index = shellTab.value);
  }

  void _select(int i) {
    shellTab.value = i;
    setState(() => _index = i);
  }

  static const _destinations = [
    (Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, '首页'),
    (Icons.explore_rounded, Icons.explore_outlined, '发现'),
    (Icons.leaderboard_rounded, Icons.leaderboard_outlined, '榜单'),
    (Icons.library_music_rounded, Icons.library_music_outlined, '音乐库'),
    (Icons.person_rounded, Icons.person_outline_rounded, '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final size = MediaQuery.sizeOf(context);
    final carMode = settings.deviceMode == 'car' ||
        (settings.deviceMode == 'auto' && size.width >= 720 && size.height <= 540);
    if (carMode) return const CarPage();

    final wide = settings.deviceMode == 'tablet' ||
        (settings.deviceMode != 'phone' && size.width >= 900);

    final pages = const [
      HomePage(),
      DiscoverPage(),
      ChartsPage(embedded: true),
      LibraryPage(),
      ProfilePage(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _Backdrop(accent: settings.accentColor)),
          SafeArea(
            bottom: false,
            child: wide
                ? Row(
                    children: [
                      _Rail(
                        index: _index,
                        destinations: _destinations,
                        onSelect: _select,
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: IndexedStack(index: _index, children: pages)),
                    ],
                  )
                : IndexedStack(index: _index, children: pages),
          ),
          if (!wide)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomArea(
                index: _index,
                destinations: _destinations,
                onSelect: _select,
              ),
            ),
          if (wide)
            Positioned(
              left: 96,
              right: 24,
              bottom: 18,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: const MiniPlayer(floating: true),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  final Color accent;
  const _Backdrop({required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -180,
            left: -120,
            child: _Blob(color: accent.withValues(alpha: isDark ? 0.16 : 0.12), size: 460),
          ),
          Positioned(
            top: 120,
            right: -200,
            child: _Blob(color: AppTheme.mint.withValues(alpha: isDark ? 0.09 : 0.12), size: 520),
          ),
          Positioned(
            bottom: -240,
            left: 200,
            child: _Blob(color: const Color(0xFF7B5CFF).withValues(alpha: isDark ? 0.08 : 0.07), size: 520),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final int index;
  final List<(IconData, IconData, String)> destinations;
  final ValueChanged<int> onSelect;

  const _Rail({required this.index, required this.destinations, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          const BrandMark(size: 17),
          const SizedBox(height: 30),
          for (var i = 0; i < destinations.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => onSelect(i),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: index == i ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        index == i ? destinations[i].$1 : destinations[i].$2,
                        size: 22,
                        color: index == i
                            ? scheme.primary
                            : scheme.onSurface.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        destinations[i].$3,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: index == i ? FontWeight.w800 : FontWeight.w500,
                          color: index == i
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.tune_rounded),
            tooltip: '设置',
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  final int index;
  final List<(IconData, IconData, String)> destinations;
  final ValueChanged<int> onSelect;

  const _BottomArea({required this.index, required this.destinations, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: scheme.outline.withValues(alpha: 0.25))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: MiniPlayer(),
            ),
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: InkResponse(
                        onTap: () => onSelect(i),
                        radius: 26,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                              decoration: BoxDecoration(
                                color: index == i
                                    ? scheme.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Icon(
                                index == i ? destinations[i].$1 : destinations[i].$2,
                                size: 21,
                                color: index == i
                                    ? scheme.primary
                                    : scheme.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              destinations[i].$3,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: index == i ? FontWeight.w800 : FontWeight.w500,
                                color: index == i
                                    ? scheme.primary
                                    : scheme.onSurface.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final bool floating;
  const MiniPlayer({super.key, this.floating = false});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/player'),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              CoverArt(url: song.coverUrl, size: 46, radius: 15, seed: song.hash.hashCode),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              IconButton(
                onPressed: player.toggle,
                icon: Icon(
                  player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  size: 34,
                  color: scheme.primary,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: player.next,
                icon: const Icon(Icons.skip_next_rounded, size: 24),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        content,
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: ValueListenableBuilder<Duration>(
            valueListenable: player.position,
            builder: (context, pos, _) {
              final total = player.duration.inMilliseconds;
              final value = total <= 0 ? 0.0 : (pos.inMilliseconds / total).clamp(0.0, 1.0);
              return ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Keeps type references used by pages that import this file.
typedef ShellSong = Song;
