import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../player/player_controller.dart';

class LyricsView extends StatefulWidget {
  final bool expanded;
  final double scale;
  final bool glow;
  const LyricsView({super.key, this.expanded = false, this.scale = 1, this.glow = true});

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scroll = ScrollController();
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    final player = context.read<PlayerController>();
    player.lyricIndex.addListener(_onIndex);
    // 进入歌词页时直接定位到当前播放行，而不是停在开头。
    WidgetsBinding.instance.addPostFrameCallback((_) => _onIndex());
  }

  @override
  void dispose() {
    context.read<PlayerController>().lyricIndex.removeListener(_onIndex);
    _scroll.dispose();
    super.dispose();
  }

  void _onIndex() {
    final player = context.read<PlayerController>();
    final i = player.lyricIndex.value;
    if (i < 0 || i == _lastIndex) return;
    _lastIndex = i;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final extent = (widget.expanded ? 66.0 : 42.0) * widget.scale;
      final target = (i * extent - _scroll.position.viewportDimension * 0.42).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 460), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final doc = player.lyric;
    final scheme = Theme.of(context).colorScheme;
    if (doc == null || doc.lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 36, color: scheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 10),
            Text('暂无歌词',
                style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      );
    }
    return ValueListenableBuilder<Duration>(
      valueListenable: player.position,
      builder: (context, pos, _) {
        return ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.symmetric(vertical: widget.expanded ? 140 : 26),
          itemExtent: (widget.expanded ? 66.0 : 42.0) * widget.scale,
          itemCount: doc.lines.length,
          itemBuilder: (context, i) {
            final line = doc.lines[i];
            final active = i == player.lyricIndex.value;
            final passed = i < player.lyricIndex.value;
            return GestureDetector(
              onTap: () => player.seek(Duration(milliseconds: line.startMs)),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedScale(
                  scale: active ? 1.04 : 1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  child: _LyricLineText(
                    line: line,
                    active: active,
                    passed: passed,
                    positionMs: pos.inMilliseconds,
                    scale: widget.scale,
                    glow: widget.glow,
                    expanded: widget.expanded,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LyricLineText extends StatelessWidget {
  final LyricLine line;
  final bool active;
  final bool passed;
  final int positionMs;
  final double scale;
  final bool glow;
  final bool expanded;

  const _LyricLineText({
    required this.line,
    required this.active,
    required this.passed,
    required this.positionMs,
    required this.scale,
    required this.glow,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = active
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: passed ? 0.3 : 0.55);
    final fontSize = (expanded ? 22.0 : 15.0) * scale;
    TextStyle style = TextStyle(
      fontSize: fontSize,
      height: 1.35,
      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
      color: baseColor,
      shadows: active && glow
          ? [Shadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 18)]
          : null,
    );

    if (!line.hasWords || !active) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Text(
          line.text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      );
    }

    final spans = <TextSpan>[];
    for (final w in line.words) {
      final done = positionMs >= w.startMs + w.durationMs;
      final singing = positionMs >= w.startMs && positionMs < w.startMs + w.durationMs;
      spans.add(TextSpan(
        text: w.text,
        style: style.copyWith(
          color: done || singing
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.4),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Text.rich(TextSpan(children: spans), textAlign: TextAlign.center, maxLines: 2),
    );
  }
}

class LyricPreview extends StatelessWidget {
  final double scale;
  const LyricPreview({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    final doc = player.lyric;
    if (doc == null || doc.lines.isEmpty) {
      return SizedBox(
        height: 66,
        child: Center(
          child: Text('♪ 暂无歌词',
              style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.35))),
        ),
      );
    }
    return ValueListenableBuilder<int>(
      valueListenable: player.lyricIndex,
      builder: (context, idx, _) {
        final i = idx < 0 ? 0 : idx;
        final current = doc.lines[i];
        final prev = i > 0 ? doc.lines[i - 1] : null;
        final next = i + 1 < doc.lines.length ? doc.lines[i + 1] : null;
        return SizedBox(
          height: 100 * scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (prev != null)
                Text(prev.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12 * scale,
                        color: scheme.onSurface.withValues(alpha: 0.28))),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(current.text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16 * scale,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        shadows: [
                          Shadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 14)
                        ])),
              ),
              const SizedBox(height: 8),
              if (next != null)
                Text(next.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12 * scale,
                        color: scheme.onSurface.withValues(alpha: 0.28))),
            ],
          ),
        );
      },
    );
  }
}
