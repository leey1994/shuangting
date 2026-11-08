import 'package:flutter/material.dart' hide Text;
import './widgets/l10n_text.dart';

import '../core/download_service.dart';
import '../core/library_store.dart';
import '../core/models.dart';
import '../core/player/player_service.dart';
import '../core/theme.dart';
import 'pages/lyric_search_page.dart';
import 'widgets/common.dart';

Future<void> showSongActions(
  BuildContext context,
  MusicItem song, {
  List<MusicItem>? contextSongs,
  VoidCallback? onRemoved,
  String? removeLabel,
}) async {
  final lib = LibraryStore.instance;
  final isFav = lib.isFavorite(song);
  final service = PlayerService.instance;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    CoverImage(path: song.artwork, size: 52, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(song.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _ActionTile(icon: Icons.playlist_play_rounded, label: '下一首播放', onTap: () {
                Navigator.pop(context);
                service.playNext(song);
                showToast(context, '已加入下一首');
              }),
              _ActionTile(icon: Icons.library_add_rounded, label: '添加到歌单', onTap: () {
                Navigator.pop(context);
                showAddToPlaylistSheet(context, song);
              }),
              _ActionTile(
                icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: isFav ? '取消收藏' : '收藏',
                color: isFav ? Theme.of(context).colorScheme.primary : null,
                onTap: () async {
                  Navigator.pop(context);
                  final added = await lib.toggleFavorite(song);
                  if (context.mounted) showToast(context, added ? '已收藏' : '已取消收藏');
                },
              ),
              _ActionTile(icon: Icons.download_rounded, label: '下载', onTap: () {
                Navigator.pop(context);
                DownloadService.instance.enqueue(song);
                showToast(context, '已加入下载队列');
              }),
              _ActionTile(icon: Icons.lyrics_rounded, label: '关联歌词', onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => LyricSearchPage(song: song)));
              }),
              _ActionTile(icon: Icons.info_outline_rounded, label: '歌曲信息', onTap: () {
                Navigator.pop(context);
                showSongInfo(context, song);
              }),
              if (onRemoved != null)
                _ActionTile(
                  icon: Icons.remove_circle_outline_rounded,
                  label: removeLabel ?? '从歌单移除',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    onRemoved();
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppPalette.muted(context), size: 22),
      title: Text(label, style: TextStyle(fontSize: 14.5, color: color)),
      onTap: onTap,
      dense: true,
    );
  }
}

Future<void> showAddToPlaylistSheet(BuildContext context, MusicItem song) async {
  final lib = LibraryStore.instance;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final playlists = [lib.favorites, ...lib.userPlaylists];
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Tr('添加到歌单', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final name = await promptText(context, title: '新建歌单', hint: '歌单名称');
                      if (name != null && name.trim().isNotEmpty) {
                        final p = lib.createPlaylist(name.trim());
                        await lib.addSongsToPlaylist(p, [song]);
                        if (context.mounted) {
                          Navigator.pop(context);
                          showToast(context, '已添加到「${p.name}」');
                        }
                      }
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('新建'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, i) {
                  final p = playlists[i];
                  return ListTile(
                    leading: CoverImage(path: p.cover, size: 42, radius: 10),
                    title: Text(p.name),
                    subtitle: Text('${p.songs.length} 首', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                    trailing: const Icon(Icons.add_rounded, size: 20),
                    onTap: () async {
                      await lib.addSongsToPlaylist(p, [song]);
                      if (context.mounted) {
                        Navigator.pop(context);
                        showToast(context, '已添加到「${p.name}」');
                      }
                    },
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

Future<String?> promptText(BuildContext context,
    {required String title, String? hint, String initial = '', bool obscure = false}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t(title)),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: obscure,
        decoration: InputDecoration(hintText: hint == null ? null : t(hint)),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Tr('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Tr('确定')),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<void> showSongInfo(BuildContext context, MusicItem song) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Tr('歌曲信息'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('标题', song.title),
            _infoRow('歌手', song.displayArtist),
            _infoRow('专辑', song.displayAlbum),
            _infoRow('来源', song.platform),
            _infoRow('ID', song.id),
            _infoRow('时长', song.durationText),
            if (song.localPath != null) _infoRow('本地路径', song.localPath!),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
    ),
  );
}

Widget _infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          SelectableText(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );

Future<bool> confirmDialog(BuildContext context, String title, {String? content, String okLabel = '确定'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t(title)),
      content: content == null ? null : Text(t(content)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Tr('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          child: Text(t(okLabel)),
        ),
      ],
    ),
  );
  return result ?? false;
}
