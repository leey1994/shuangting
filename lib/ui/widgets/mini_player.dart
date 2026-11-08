import 'package:flutter/material.dart' hide Text;
import './l10n_text.dart';

import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../pages/player_page.dart';
import 'common.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static void openPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => const PlayerPage(),
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: player.pageListenable,
        builder: (context, _) {
          final song = player.current;
          return AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: song == null ? 0 : 76,
              child: song == null ? null : _MiniPlayerBar(context: context, player: player),
            ),
          );
        },
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({required this.context, required this.player});
  final BuildContext context;
  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final song = player.current!;
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onVerticalDragEnd: (data) {
          final velocity = data.primaryVelocity;
          if (velocity != null && velocity < -420) {
            MiniPlayer.openPlayer(context);
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => MiniPlayer.openPlayer(context),
            child: GlassPanel(
              radius: 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 3, 6),
                    child: Row(
                      children: [
                        CoverImage(path: song.artwork, size: 42, radius: 12),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(song.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: player.previous,
                          icon: const Icon(Icons.skip_previous_rounded, size: 25),
                          visualDensity: VisualDensity.compact,
                          tooltip: t('上一首'),
                        ),
                        if (player.loading)
                          const SizedBox(width: 34, height: 34, child: Padding(padding: EdgeInsets.all(9), child: CircularProgressIndicator(strokeWidth: 2)))
                        else
                          IconButton(
                            onPressed: player.toggle,
                            icon: Icon(player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, size: 36, color: primary),
                            visualDensity: VisualDensity.compact,
                          ),
                        IconButton(
                          onPressed: player.next,
                          icon: const Icon(Icons.skip_next_rounded, size: 26),
                          visualDensity: VisualDensity.compact,
                          tooltip: t('下一首'),
                        ),
                      ],
                    ),
                  ),
                  _MiniProgressBar(player: player),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.player});
  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: player.progressListenable,
        builder: (context, _) {
          final progress = player.duration.inMilliseconds <= 0
              ? 0.0
              : (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0).toDouble();
          return LayoutBuilder(
            builder: (context, constraints) {
              void update(double globalX) {
                final box = context.findRenderObject() as RenderBox;
                final ratio = ((globalX - box.localToGlobal(Offset.zero).dx) / constraints.maxWidth).clamp(0.0, 1.0);
                player.seekToRatio(ratio.toDouble());
              }

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (d) => update(d.globalPosition.dx),
                onHorizontalDragStart: (d) => update(d.globalPosition.dx),
                onHorizontalDragUpdate: (d) => update(d.globalPosition.dx),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(primary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
