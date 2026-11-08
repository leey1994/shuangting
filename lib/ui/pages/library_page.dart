import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/download_service.dart';
import '../../core/library_store.dart';
import '../../core/local_library.dart';
import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'local_page.dart';
import 'media_detail_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LibraryStore.instance,
        DownloadService.instance,
        LocalLibrary.instance,
      ]),
      builder: (context, _) {
        final lib = LibraryStore.instance;
        final fav = lib.favorites;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Tr('音乐库'),
            actions: [
              IconButton(
                onPressed: () => _createPlaylist(context),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(child: _QuickCard(icon: Icons.favorite_rounded, title: '我喜欢', count: fav.songs.length, unit: '首', color: const Color(0xFFFF5C8A), onTap: () => _openPlaylist(context, fav))),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickCard(icon: Icons.download_rounded, title: '下载管理', count: DownloadService.instance.tasks.length, unit: '项', color: const Color(0xFFF5A524), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsPage())))),
                    const SizedBox(width: 10),
                    Expanded(child: _QuickCard(icon: Icons.folder_special_rounded, title: '本地音乐', count: LocalLibrary.instance.songs.length, unit: '首', color: const Color(0xFF37C08A), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocalMusicPage())))),
                  ],
                ),
              ),
              if (lib.history.isNotEmpty) ...[
                SectionTitle('最近播放', trailing: '全部', onTrailing: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage()))),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: lib.history.take(10).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final song = lib.history[i].song;
                      return SizedBox(
                        width: 96,
                        child: GestureDetector(
                          onTap: () {
                            final songs = lib.history.map((e) => e.song).toList();
                            PlayerService.instance.playQueue(songs, startIndex: i);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CoverImage(path: song.artwork, size: 96, radius: 18),
                              const SizedBox(height: 6),
                              Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                              Text(song.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: AppPalette.muted(context))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              SectionTitle('我的歌单', trailing: '新建', onTrailing: () => _createPlaylist(context)),
              if (lib.userPlaylists.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Text('还没有自建歌单，点右上角新建一个吧', style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                )
              else
                for (final p in lib.userPlaylists)
                  ListTile(
                    leading: CoverImage(path: p.cover, size: 52, radius: 14),
                    title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${p.songs.length} 首', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                    trailing: IconButton(
                      onPressed: () => _playlistMenu(context, p),
                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
                    ),
                    onTap: () => _openPlaylist(context, p),
                    onLongPress: () => _playlistMenu(context, p),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _openPlaylist(BuildContext context, Playlist p) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MusicListDetailPage(
        title: p.name,
        artwork: p.cover,
        subtitle: p.description,
        playlist: p,
        kind: MediaListKind.localPlaylist,
      ),
    ));
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final name = await promptText(context, title: '新建歌单', hint: '给歌单起个名字');
    if (name != null && name.trim().isNotEmpty) {
      LibraryStore.instance.createPlaylist(name.trim());
    }
  }

  Future<void> _playlistMenu(BuildContext context, Playlist p) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_play_rounded),
              title: const Tr('播放全部'),
              onTap: () {
                Navigator.pop(context);
                if (p.songs.isNotEmpty) PlayerService.instance.playQueue(p.songs);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('重命名'),
              onTap: () async {
                Navigator.pop(context);
                final name = await promptText(context, title: '重命名歌单', initial: p.name);
                if (name != null && name.trim().isNotEmpty) {
                  await LibraryStore.instance.renamePlaylist(p, name.trim());
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('删除歌单', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                if (await confirmDialog(context, '删除歌单「${p.name}」？')) {
                  await LibraryStore.instance.deletePlaylist(p);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.unit,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final int count;
  final String unit;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(title), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Text('$count ${t(unit)}', style: TextStyle(fontSize: 10.5, color: AppPalette.muted(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
