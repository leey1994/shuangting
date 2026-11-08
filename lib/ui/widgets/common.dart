import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart' hide Text;
import './l10n_text.dart';

import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';

/// 直接按当前语言翻译字面量，保持 const 可用的 Text 替代品。
class Tr extends StatelessWidget {
  const Tr(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) => Text(
        L10n.instance.t(text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
}

class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.path,
    this.size,
    this.radius = 16,
    this.width,
    this.height,
  });

  final String path;
  final double? size;
  final double radius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final radiusValue = BorderRadius.circular(radius);
    Widget child;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      child = Image.network(
        path,
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        cacheWidth: w != null ? (w * 2).round() : null,
        errorBuilder: (_, _, _) => _placeholder(context),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _placeholder(context, loading: true),
      );
    } else if (path.isNotEmpty) {
      child = Image.file(
        File(path),
        width: w,
        height: h,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        cacheWidth: w != null ? (w * 2).round() : null,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    } else {
      child = _placeholder(context);
    }
    return ClipRRect(borderRadius: radiusValue, child: SizedBox(width: w, height: h, child: child));
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final dark = AppPalette.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF262C37), Color(0xFF171B22)]
              : const [Color(0xFFF2EAE0), Color(0xFFE8DFD4)],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.graphic_eq_rounded, color: AppPalette.muted(context).withValues(alpha: 0.6), size: 26),
      ),
    );
  }
}

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final settings = Settings.instance;
    final path = settings.get<String>('backgroundPath');
    final opacity = settings.get<double>('backgroundOpacity');
    final blur = settings.get<double>('backgroundBlur');
    final exists = path.isNotEmpty && File(path).existsSync();
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: Theme.of(context).colorScheme.surface)),
        if (exists)
          Positioned.fill(
            child: RepaintBoundary(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 720,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.low,
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.onTrailing});
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Text(t(title), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
          const Spacer(),
          if (trailing != null)
            TextButton(
              onPressed: onTrailing,
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.muted(context),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Row(children: [Text(t(trailing!), style: const TextStyle(fontSize: 12)), const Icon(Icons.chevron_right, size: 16)]),
            ),
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.text, this.action, this.actionLabel, this.icon});
  final String text;
  final VoidCallback? action;
  final String? actionLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon ?? Icons.queue_music_rounded, size: 34, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(t(text), textAlign: TextAlign.center, style: TextStyle(color: AppPalette.muted(context), height: 1.5)),
            if (action != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: action, child: Text(t(actionLabel ?? '确定'))),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.text});
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
          if (text != null) ...[
            const SizedBox(height: 12),
            Text(t(text!), style: TextStyle(color: AppPalette.muted(context), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class PlayIndicator extends StatefulWidget {
  const PlayIndicator({super.key, this.playing = true, this.color});
  final bool playing;
  final Color? color;

  @override
  State<PlayIndicator> createState() => _PlayIndicatorState();
}

class _PlayIndicatorState extends State<PlayIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 0.35,
  );

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PlayIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.playing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final h = widget.playing ? 6.0 + 12.0 * ((t + i * 0.23) % 1.0) : 4.0 + 8.0 * ((0.35 + i * 0.17) % 1.0);
            return Container(
              width: 2.6,
              height: h,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            );
          }),
        );
      },
    );
  }
}

class MusicTile extends StatelessWidget {
  const MusicTile({
    super.key,
    required this.song,
    this.index,
    this.onTap,
    this.onMore,
    this.trailing,
    this.isCurrent,
  });

  final MusicItem song;
  final int? index;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final Widget? trailing;
  final bool? isCurrent;

  @override
  Widget build(BuildContext context) {
    final player = PlayerService.instance;
    return ListenableBuilder(
      listenable: player.pageListenable,
      builder: (context, _) {
        final current = isCurrent ?? (player.currentKey == song.key);
        return _build(context, current, player);
      },
    );
  }

  Widget _build(BuildContext context, bool current, PlayerService player) {
    final showIndex = index != null && !current;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (showIndex)
              SizedBox(
                width: 28,
                child: Text(
                  '${index! + 1}'.padLeft(2, '0'),
                  style: TextStyle(color: AppPalette.muted(context), fontSize: 12),
                ),
              ),
            CoverImage(path: song.artwork, size: 48, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.title.isEmpty ? L10n.instance.t('未知曲目') : song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                            color: current ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                      ),
                      if (current) ...[
                        const SizedBox(width: 8),
                        PlayIndicator(playing: player.playing),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${song.displayArtist}${song.album.isEmpty ? '' : ' · ${song.album}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: AppPalette.muted(context)),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onMore != null)
              IconButton(
                onPressed: onMore,
                icon: Icon(Icons.more_horiz_rounded, color: AppPalette.muted(context), size: 20),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class SheetGridCard extends StatelessWidget {
  const SheetGridCard({super.key, required this.title, required this.artwork, this.subtitle, this.onTap});
  final String title;
  final String artwork;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(path: artwork, radius: 20),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.3)),
          if (subtitle != null)
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.selected, this.onTap, this.count});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              L10n.instance.t(label),
              style: TextStyle(
                fontSize: 12.5,
                color: selected ? Colors.white : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 5),
              Text('$count', style: TextStyle(fontSize: 10, color: selected ? Colors.white70 : AppPalette.muted(context))),
            ],
          ],
        ),
      ),
    );
  }
}

void showToast(BuildContext context, String text) {
  final message = L10n.instance.t(text);
  final view = View.maybeOf(context);
  final bottomInset = (view?.padding.bottom ?? 0) + 96;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(24, 24, 24, bottomInset),
      duration: const Duration(milliseconds: 2200),
    ));
}

String t(String zh) => L10n.instance.t(zh);

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding, this.radius = 22, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = AppPalette.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? (dark ? const Color(0xCC191D24) : const Color(0xE6FFFFFF)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          ),
          child: child,
        ),
      ),
    );
  }
}
