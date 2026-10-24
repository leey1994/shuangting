import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

/// 横屏车机界面：大字号、大按钮、弱化滚动，适配 720p 以下的车机屏幕。
class CarPage extends StatefulWidget {
  const CarPage({super.key});

  @override
  State<CarPage> createState() => _CarPageState();
}

class _CarPageState extends State<CarPage> {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _exitCarMode() {
    context.read<SettingsModel>().deviceMode = 'phone';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已切回手机界面，可在设置中重新开启车机模式')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    final song = player.current;
    final colors = AppTheme.coverGradient(song?.hash.hashCode ?? 7);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(colors.first, Colors.black, 0.72)!,
                    const Color(0xFF07090E),
                    Color.lerp(colors.last, Colors.black, 0.78)!,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
              child: Column(
                children: [
                  _TopBar(now: _now, onExit: _exitCarMode),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _NowPlayingPanel(player: player, song: song),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          flex: 6,
                          child: _ControlPanel(player: player, song: song, scheme: scheme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QueueStrip(
                    player: player,
                    fallback: [
                      ...library.history.take(6),
                      ...library.favorites.take(6),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final DateTime now;
  final VoidCallback onExit;
  const _TopBar({required this.now, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        const BrandMark(size: 18),
        const SizedBox(width: 14),
        Text(time,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface.withValues(alpha: 0.55))),
        const Spacer(),
        _NavChip(icon: Icons.leaderboard_rounded, label: '榜单', route: '/charts'),
        const SizedBox(width: 8),
        _NavChip(icon: Icons.search_rounded, label: '搜索', route: '/search'),
        const SizedBox(width: 8),
        _NavChip(icon: Icons.library_music_rounded, label: '音乐库', route: '/favorites'),
        const SizedBox(width: 8),
        _NavChip(icon: Icons.tune_rounded, label: '设置', route: '/settings'),
        const SizedBox(width: 10),
        TextButton.icon(
          onPressed: onExit,
          icon: const Icon(Icons.phone_android_rounded, size: 17),
          label: const Text('退出车机'),
          style: TextButton.styleFrom(
            foregroundColor: scheme.onSurface.withValues(alpha: 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _NavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  const _NavChip({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onSurface.withValues(alpha: 0.75)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.75))),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingPanel extends StatelessWidget {
  final PlayerController player;
  final Song? song;
  const _NowPlayingPanel({required this.player, required this.song});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (song == null) {
      return Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_rounded,
                size: 64, color: scheme.primary.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            const Text('爽听 · 车机模式',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('从下方挑一首最近听过的歌，或打开榜单开始播放',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: scheme.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          CoverArt(
            url: song!.coverUrl,
            size: 168,
            radius: 24,
            seed: song!.hash.hashCode,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(song!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text(song!.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.55))),
                const SizedBox(height: 16),
                ValueListenableBuilder<int>(
                  valueListenable: player.lyricIndex,
                  builder: (context, idx, _) {
                    final lines = player.lyric?.lines ?? const [];
                    final text = idx >= 0 && idx < lines.length
                        ? lines[idx].text
                        : (player.lyric == null ? '正在加载歌词…' : '纯音乐，请欣赏');
                    return Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    QualityTag(label: qualityName(player.activeQuality), color: scheme.primary),
                    const SizedBox(width: 8),
                    if (player.loading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: scheme.primary),
                      ),
                    if (player.error != null)
                      Flexible(
                        child: Text(player.error!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFFFF7A8C))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final PlayerController player;
  final Song? song;
  final ColorScheme scheme;
  const _ControlPanel({required this.player, required this.song, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final enabled = song != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<Duration>(
                  valueListenable: player.position,
                  builder: (context, pos, _) {
                    final total = player.duration.inMilliseconds;
                    final value = total <= 0
                        ? 0.0
                        : (pos.inMilliseconds / total).clamp(0.0, 1.0);
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                          ),
                          child: Slider(
                            value: value,
                            onChanged: enabled ? (v) => player.seek(
                                Duration(milliseconds: (v * total).round())) : null,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              Text(formatMs(pos.inMilliseconds),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurface.withValues(alpha: 0.45))),
                              const Spacer(),
                              Text(formatMs(player.duration.inMilliseconds),
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: scheme.onSurface.withValues(alpha: 0.45))),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: Icons.shuffle_rounded,
                      size: 46,
                      active: player.shuffle,
                      onTap: player.toggleShuffle,
                    ),
                    const SizedBox(width: 16),
                    _RoundButton(
                      icon: Icons.skip_previous_rounded,
                      size: 60,
                      onTap: enabled ? () => player.previous() : null,
                    ),
                    const SizedBox(width: 18),
                    _PlayButton(player: player, enabled: enabled),
                    const SizedBox(width: 18),
                    _RoundButton(
                      icon: Icons.skip_next_rounded,
                      size: 60,
                      onTap: enabled ? () => player.next() : null,
                    ),
                    const SizedBox(width: 16),
                    _RoundButton(
                      icon: switch (player.loop) {
                        PlayerLoop.one => Icons.repeat_one_rounded,
                        PlayerLoop.off => Icons.repeat_rounded,
                        PlayerLoop.all => Icons.repeat_rounded,
                      },
                      size: 46,
                      active: player.loop != PlayerLoop.off,
                      onTap: player.cycleLoop,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.volume_down_rounded,
                  size: 19, color: scheme.onSurface.withValues(alpha: 0.45)),
              Expanded(
                child: Slider(
                  value: player.volume,
                  onChanged: (v) => player.setVolume(v),
                ),
              ),
              Icon(Icons.volume_up_rounded,
                  size: 19, color: scheme.onSurface.withValues(alpha: 0.45)),
              const SizedBox(width: 14),
              IconButton(
                onPressed: enabled ? () => Navigator.pushNamed(context, '/player') : null,
                icon: const Icon(Icons.open_in_full_rounded, size: 19),
                tooltip: '完整播放页',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final PlayerController player;
  final bool enabled;
  const _PlayButton({required this.player, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: enabled ? scheme.primary : scheme.primary.withValues(alpha: 0.3),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? player.toggle : null,
        child: SizedBox(
          width: 88,
          height: 88,
          child: player.loading
              ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Icon(
                  player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 48,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool active;
  final VoidCallback? onTap;
  const _RoundButton({
    required this.icon,
    required this.size,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active
          ? scheme.primary.withValues(alpha: 0.16)
          : Colors.white.withValues(alpha: 0.05),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.44,
            color: active
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: onTap == null ? 0.25 : 0.78),
          ),
        ),
      ),
    );
  }
}

class _QueueStrip extends StatelessWidget {
  final PlayerController player;
  final List<Song> fallback;
  const _QueueStrip({required this.player, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final songs = player.queue.isNotEmpty ? player.queue : fallback;
    if (songs.isEmpty) {
      return const SizedBox(height: 4);
    }
    final start = player.queue.isEmpty ? 0 : player.index;
    final list = songs.skip(start).take(8).toList();
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = list[i];
          final active = player.current?.hash == s.hash;
          return Material(
            color: active
                ? scheme.primary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (player.queue.isEmpty) {
                  player.playSong(s, newQueue: fallback);
                } else {
                  player.playSong(s);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 16, 7),
                child: Row(
                  children: [
                    CoverArt(
                      url: s.coverUrl,
                      size: 46,
                      radius: 12,
                      seed: s.hash.hashCode,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(s.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                                  color: active ? scheme.primary : scheme.onSurface)),
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: 150,
                          child: Text(s.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: scheme.onSurface.withValues(alpha: 0.45))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
