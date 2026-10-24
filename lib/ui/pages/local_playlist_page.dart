import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

class LocalPlaylistPage extends StatelessWidget {
  final String playlistId;
  const LocalPlaylistPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    final index = library.playlists.indexWhere((e) => e.id == playlistId);
    if (index < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(title: '歌单不存在', subtitle: '它可能已被删除'),
      );
    }
    final pl = library.playlists[index];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.coverGradient(pl.id.hashCode, isDark: isDark);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (v) async {
                  if (v == 'rename') {
                    final controller = TextEditingController(text: pl.name);
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('重命名歌单'),
                        content: TextField(controller: controller, autofocus: true),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, controller.text),
                              child: const Text('保存')),
                        ],
                      ),
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      await library.renamePlaylist(pl.id, name.trim());
                    }
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除歌单？'),
                        content: Text('「${pl.name}」将从音乐库移除，歌曲文件不受影响。'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await library.deletePlaylist(pl.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('重命名')),
                  PopupMenuItem(value: 'delete', child: Text('删除歌单')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.first.withValues(alpha: 0.55), scheme.surface],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          CoverArt(
                            url: pl.songs.isNotEmpty ? pl.songs.first.coverUrl : '',
                            size: 116,
                            radius: 24,
                            seed: pl.id.hashCode,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(pl.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 4),
                                Text('自建歌单 · ${pl.songs.length} 首',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurface.withValues(alpha: 0.55))),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: pl.songs.isEmpty
                                          ? null
                                          : () => playSongList(context, pl.songs, 0),
                                      icon: const Icon(Icons.play_arrow_rounded),
                                      label: const Text('播放全部'),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton.filledTonal(
                                      onPressed: pl.songs.isEmpty
                                          ? null
                                          : () {
                                              final player = context.read<PlayerController>();
                                              if (!player.shuffle) player.toggleShuffle();
                                              playSongList(context, pl.songs, 0);
                                            },
                                      icon: const Icon(Icons.shuffle_rounded, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (pl.songs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(
                icon: Icons.music_note_rounded,
                title: '歌单还是空的',
                subtitle: '在歌曲菜单里选择「添加到歌单」',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = pl.songs[i];
                  return SongTile(
                    song: s,
                    index: i,
                    showIndex: true,
                    onTap: () => playSongList(context, pl.songs, i),
                    onMore: () => openSongMenu(context, s),
                    trailing: IconButton(
                      onPressed: () => library.removeFromPlaylist(pl.id, s.hash),
                      icon: Icon(Icons.remove_circle_outline_rounded,
                          size: 18, color: scheme.onSurface.withValues(alpha: 0.35)),
                    ),
                  );
                },
                childCount: pl.songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }
}
