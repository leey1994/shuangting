import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/download_manager.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';

class BrandMark extends StatelessWidget {
  final double size;
  final bool withSub;
  const BrandMark({super.key, this.size = 24, this.withSub = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size * 1.35,
          height: size * 1.35,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.42),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, AppTheme.mint],
            ),
          ),
          alignment: Alignment.center,
          child: Text('爽',
              style: TextStyle(
                  fontSize: size * 0.8,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0A0C12))),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('爽听',
                style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    height: 1)),
            if (withSub)
              Text('SHUANGTING',
                  style: TextStyle(
                      fontSize: size * 0.34,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
          ],
        ),
      ],
    );
  }
}

class CoverArt extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  final int seed;
  final bool vinyl;

  const CoverArt({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 16,
    this.seed = 0,
    this.vinyl = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.coverGradient(seed, isDark: isDark);
    final fallback = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Icon(Icons.graphic_eq_rounded,
            color: Colors.white.withValues(alpha: 0.85), size: size * 0.32),
      ),
    );
    Widget art = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
              ),
      ),
    );
    if (vinyl) {
      art = Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          ClipOval(
            child: SizedBox(
              width: size * 0.92,
              height: size * 0.92,
              child: url.isEmpty
                  ? fallback
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => fallback,
                      loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                    ),
            ),
          ),
          Container(
            width: size * 0.16,
            height: size * 0.16,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
          ),
        ],
      );
    }
    return art;
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.45))),
                  ),
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_rounded, size: 15),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class QualityTag extends StatelessWidget {
  final String label;
  final Color color;
  const QualityTag({super.key, required this.label, this.color = AppTheme.mint});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4)),
    );
  }
}

class SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final bool showIndex;
  final bool dense;
  final bool showCover;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsets padding;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.index = 0,
    this.showIndex = false,
    this.dense = false,
    this.showCover = true,
    this.onMore,
    this.trailing,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final player = context.watch<PlayerController>();
    final active = player.current?.hash == song.hash;
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) leading!,
            if (showIndex)
              SizedBox(
                width: 28,
                child: active
                    ? Icon(Icons.graphic_eq_rounded, size: 17, color: scheme.primary)
                    : Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.35))),
              ),
            if (showCover) ...[
              CoverArt(
                  url: song.coverUrl,
                  size: dense ? 44 : 54,
                  radius: dense ? 12 : 15,
                  seed: song.hash.hashCode),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: dense ? 14 : 15,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                            color: active ? scheme.primary : scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      QualityTag(label: song.qualityTag, color: active ? scheme.primary : AppTheme.mint),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.album.isEmpty ? song.artist : '${song.artist} · ${song.album}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.45)),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onMore != null)
              IconButton(
                onPressed: onMore,
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: scheme.onSurface.withValues(alpha: 0.5)),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({
    super.key,
    this.icon = Icons.music_off_rounded,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.45))),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  final String label;
  const LoadingView({super.key, this.label = '加载中…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.cloud_off_rounded,
      title: message,
      subtitle: '检查网络后重试',
      action: onRetry == null
          ? null
          : FilledButton.tonal(onPressed: onRetry, child: const Text('重新加载')),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ??
                (isDark
                    ? Colors.white.withValues(alpha: 0.055)
                    : Colors.white.withValues(alpha: 0.72)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white,
                width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

Future<void> playSongList(BuildContext context, List<Song> songs, int index) async {
  if (songs.isEmpty) return;
  final player = context.read<PlayerController>();
  player.exitFm();
  await player.playSong(songs[index], newQueue: songs, startIndex: index);
}

void openSongMenu(BuildContext context, Song song) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => _SongMenuSheet(song: song),
  );
}

class _SongMenuSheet extends StatelessWidget {
  final Song song;
  const _SongMenuSheet({required this.song});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final player = context.read<PlayerController>();
    final downloads = context.read<DownloadManager>();
    final scheme = Theme.of(context).colorScheme;
    final fav = library.isFavorite(song);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CoverArt(url: song.coverUrl, size: 48, radius: 12, seed: song.hash.hashCode),
              title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 20),
            _MenuRow(
              icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: fav ? scheme.primary : null,
              label: fav ? '取消收藏' : '收藏到喜欢',
              onTap: () {
                library.toggleFavorite(song);
                Navigator.pop(context);
              },
            ),
            _MenuRow(
              icon: Icons.playlist_play_rounded,
              label: '下一首播放',
              onTap: () {
                player.addToQueueNext(song);
                Navigator.pop(context);
                _toast(context, '已加入下一首播放');
              },
            ),
            _MenuRow(
              icon: Icons.queue_music_rounded,
              label: '添加到播放队列',
              onTap: () {
                player.appendToQueue(song);
                Navigator.pop(context);
                _toast(context, '已加入播放队列');
              },
            ),
            _MenuRow(
              icon: Icons.playlist_add_rounded,
              label: '添加到歌单',
              onTap: () {
                Navigator.pop(context);
                showAddToPlaylist(context, song);
              },
            ),
            _MenuRow(
              icon: Icons.download_rounded,
              label: downloads.isActive(song.hash) ? '正在下载…' : '下载到本地',
              onTap: () {
                downloads.enqueue(song);
                Navigator.pop(context);
                _toast(context, '已开始下载');
              },
            ),
            if (song.artistId > 0)
              _MenuRow(
                icon: Icons.person_rounded,
                label: '查看歌手：${song.artist}',
                onTap: () {
                  Navigator.pop(context);
                  openArtist(context, song.artistId, song.artist);
                },
              ),
            if (song.albumId > 0)
              _MenuRow(
                icon: Icons.album_rounded,
                label: '查看专辑：${song.album}',
                onTap: () {
                  Navigator.pop(context);
                  openAlbum(context, song.albumId, song.album);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
      dense: true,
    );
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<void> showAddToPlaylist(BuildContext context, Song song) async {
  final library = context.read<LibraryModel>();
  final scheme = Theme.of(context).colorScheme;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Text('添加到歌单', style: Theme.of(ctx).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final name = await _promptName(ctx);
                    if (name != null && name.isNotEmpty) {
                      final pl = await library.createPlaylist(name, [song]);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _toast(context, '已创建「${pl.name}」');
                      }
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('新建'),
                ),
              ],
            ),
          ),
          if (library.playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('还没有自建歌单',
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45))),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: library.playlists.length,
                itemBuilder: (_, i) {
                  final pl = library.playlists[i];
                  return ListTile(
                    leading: CoverArt(
                        url: pl.songs.isNotEmpty ? pl.songs.first.coverUrl : '',
                        size: 44,
                        radius: 12,
                        seed: pl.id.hashCode),
                    title: Text(pl.name),
                    subtitle: Text('${pl.songs.length} 首'),
                    onTap: () async {
                      await library.addToPlaylist(pl.id, [song]);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _toast(context, '已添加到「${pl.name}」');
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

Future<String?> _promptName(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('新建歌单'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '给歌单取个名字'),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('创建')),
      ],
    ),
  );
  return result;
}

// Navigation helpers filled by pages through imports to avoid cycles.
void openArtist(BuildContext context, int id, String name) {
  Navigator.of(context).pushNamed('/artist', arguments: {'id': id, 'name': name});
}

void openAlbum(BuildContext context, int id, String name) {
  Navigator.of(context).pushNamed('/album', arguments: {'id': id, 'name': name});
}
