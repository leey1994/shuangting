import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/download_manager.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';
import 'local_playlist_page.dart';

class LibraryPage extends StatefulWidget {
  final int initialTab;
  final bool standalone;
  const LibraryPage({super.key, this.initialTab = 0, this.standalone = false});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with AutomaticKeepAliveClientMixin {
  static const tabs = ['收藏', '历史', '下载', '歌单', '本地'];

  late int _tab = widget.initialTab;
  bool _selecting = false;
  final Set<String> _selected = {};

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final body = Column(
      children: [
        if (!widget.standalone)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('音乐库',
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                      SizedBox(height: 3),
                      Text('你的收藏、下载与回忆', style: TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, '/search'),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            itemCount: tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final active = i == _tab;
              return GestureDetector(
                onTap: () => setState(() {
                  _tab = i;
                  _selecting = false;
                  _selected.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(tabs[i],
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? scheme.onPrimary
                              : scheme.onSurface.withValues(alpha: 0.6))),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body()),
      ],
    );
    if (widget.standalone) {
      return Scaffold(appBar: AppBar(title: Text(tabs[_tab])), body: body);
    }
    return body;
  }

  Widget _body() {
    switch (_tab) {
      case 0:
        return _favorites();
      case 1:
        return _history();
      case 2:
        return _downloads();
      case 3:
        return _playlists();
      default:
        return _local();
    }
  }

  Widget _favorites() {
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    final list = library.favorites;
    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.favorite_border_rounded,
        title: '还没有喜欢的歌',
        subtitle: '在歌曲菜单里点「收藏到喜欢」',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            children: [
              Text('${list.length} 首歌曲',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45))),
              const Spacer(),
              if (_selecting) ...[
                TextButton(
                  onPressed: () async {
                    await library.removeFavorites(_selected);
                    setState(() {
                      _selected.clear();
                      _selecting = false;
                    });
                  },
                  child: Text('删除 ${_selected.length}'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _selecting = false;
                    _selected.clear();
                  }),
                  child: const Text('完成'),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () => setState(() => _selecting = true),
                  icon: const Icon(Icons.checklist_rounded, size: 17),
                  label: const Text('多选'),
                ),
                IconButton(
                  onPressed: () {
                    final player = context.read<PlayerController>();
                    if (!player.shuffle) player.toggleShuffle();
                    playSongList(context, list, 0);
                  },
                  icon: const Icon(Icons.shuffle_rounded, size: 20),
                  tooltip: '随机播放',
                ),
                IconButton(
                  onPressed: () => playSongList(context, list, 0),
                  icon: Icon(Icons.play_circle_fill_rounded, size: 28, color: scheme.primary),
                  tooltip: '播放全部',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 150),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];
              return SongTile(
                song: s,
                index: i,
                showCover: true,
                leading: _selecting
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Checkbox(
                          value: _selected.contains(s.hash),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(s.hash);
                            } else {
                              _selected.remove(s.hash);
                            }
                          }),
                        ),
                      )
                    : null,
                onTap: () {
                  if (_selecting) {
                    setState(() {
                      if (_selected.contains(s.hash)) {
                        _selected.remove(s.hash);
                      } else {
                        _selected.add(s.hash);
                      }
                    });
                  } else {
                    playSongList(context, list, i);
                  }
                },
                onMore: _selecting ? null : () => openSongMenu(context, s),
                trailing: _selecting
                    ? null
                    : IconButton(
                        onPressed: () => library.toggleFavorite(s),
                        icon: Icon(Icons.favorite_rounded, size: 18, color: scheme.primary),
                        visualDensity: VisualDensity.compact,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _history() {
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    final list = library.history;
    if (list.isEmpty) {
      return const EmptyView(
        icon: Icons.history_rounded,
        title: '还没有播放记录',
        subtitle: '听过的歌会自动出现在这里',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
          child: Row(
            children: [
              Text('最近播放 ${list.length} 首',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45))),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('清空播放历史？'),
                      content: const Text('此操作不可恢复。'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
                      ],
                    ),
                  );
                  if (ok == true) await library.clearHistory();
                },
                icon: const Icon(Icons.delete_sweep_rounded, size: 17),
                label: const Text('清空'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 150),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final s = list[i];
              return SongTile(
                song: s,
                index: i,
                onTap: () => playSongList(context, list, i),
                onMore: () => openSongMenu(context, s),
                trailing: Text(formatDuration(s.duration),
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.35))),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _downloads() {
    final library = context.watch<LibraryModel>();
    final manager = context.watch<DownloadManager>();
    final scheme = Theme.of(context).colorScheme;
    final tasks = manager.tasks.values.where((t) => !t.done && t.error == null).toList();
    final records = library.downloads;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 150),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
          child: Row(
            children: [
              Text('已下载 ${records.length} 首',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45))),
              const Spacer(),
              if (Platform.isWindows)
                TextButton.icon(
                  onPressed: manager.openFolder,
                  icon: const Icon(Icons.folder_open_rounded, size: 17),
                  label: const Text('目录'),
                ),
            ],
          ),
        ),
        if (tasks.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
            child: Text('正在下载', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          for (final t in tasks)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  CoverArt(url: t.song.coverUrl, size: 46, radius: 12, seed: t.song.hash.hashCode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(
                            value: t.progress > 0 ? t.progress : null,
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(t.progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (records.isEmpty && tasks.isEmpty)
          const SizedBox(
            height: 380,
            child: EmptyView(
              icon: Icons.download_done_rounded,
              title: '还没有下载的歌曲',
              subtitle: '歌曲菜单里点「下载到本地」\n听过的歌也会自动缓存',
            ),
          )
        else
          ...records.map((r) => SongTile(
                song: r.song,
                onTap: () => playSongList(
                    context, records.map((e) => e.song).toList(), records.indexOf(r)),
                onMore: () => openSongMenu(context, r.song),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(qualityName(r.quality),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary)),
                        Text(formatBytes(r.size),
                            style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
                    IconButton(
                      onPressed: () => library.removeDownload(r.song.hash),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18, color: scheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _playlists() {
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 150),
      children: [
        Row(
          children: [
            Text('自建歌单 ${library.playlists.length} 个',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45))),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: () => _createPlaylist(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新建歌单'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (library.playlists.isEmpty)
          const SizedBox(
            height: 360,
            child: EmptyView(
              icon: Icons.queue_music_rounded,
              title: '创建你的第一个歌单',
              subtitle: '把喜欢的歌整理成自己的收藏夹',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 620 ? 3 : 2;
              final item = (constraints.maxWidth - (cols - 1) * 14) / cols;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: item / (item + 56),
                ),
                itemCount: library.playlists.length,
                itemBuilder: (_, i) {
                  final pl = library.playlists[i];
                  return InkWell(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => LocalPlaylistPage(playlistId: pl.id))),
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CoverArt(
                          url: pl.songs.isNotEmpty ? pl.songs.first.coverUrl : '',
                          size: item,
                          radius: 20,
                          seed: pl.id.hashCode,
                        ),
                        const SizedBox(height: 8),
                        Text(pl.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text('${pl.songs.length} 首',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _local() {
    final library = context.watch<LibraryModel>();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(bottom: 150),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
          child: Row(
            children: [
              Text('本地音乐 ${library.local.length} 首',
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.45))),
              const Spacer(),
              TextButton.icon(
                onPressed: _importLocal,
                icon: const Icon(Icons.file_open_rounded, size: 17),
                label: const Text('导入'),
              ),
            ],
          ),
        ),
        if (library.local.isEmpty)
          const SizedBox(
            height: 360,
            child: EmptyView(
              icon: Icons.folder_rounded,
              title: '导入本地音乐',
              subtitle: '支持 MP3 / FLAC / M4A / WAV 等格式\n同名 .lrc 歌词会自动识别',
            ),
          )
        else
          ...List.generate(library.local.length, (i) {
            final s = library.local[i];
            return SongTile(
              song: s,
              index: i,
              onTap: () => playSongList(context, library.local, i),
              onMore: () => openSongMenu(context, s),
              trailing: IconButton(
                onPressed: () => library.removeLocalSong(s.hash),
                icon: Icon(Icons.close_rounded,
                    size: 18, color: scheme.onSurface.withValues(alpha: 0.35)),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
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
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('创建')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty && context.mounted) {
      await context.read<LibraryModel>().createPlaylist(name);
    }
  }

  Future<void> _importLocal() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'flac', 'm4a', 'wav', 'ogg', 'aac', 'ape', 'opus'],
    );
    if (files.isEmpty) return;
    final songs = <Song>[];
    for (final f in files) {
      final path = f.path;
      if (path == null) continue;
      final hash = md5.convert(utf8.encode(path)).toString();
      songs.add(Song(
        hash: hash,
        title: p.basenameWithoutExtension(path),
        artist: '本地音乐',
        album: p.basename(p.dirname(path)),
        localPath: path,
      ));
    }
    if (!mounted) return;
    await context.read<LibraryModel>().addLocalSongs(songs);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已导入 ${songs.length} 首本地歌曲')));
    }
  }
}

class LibraryShortcutPage extends StatelessWidget {
  final int tab;
  const LibraryShortcutPage({super.key, required this.tab});

  @override
  Widget build(BuildContext context) => LibraryPage(initialTab: tab, standalone: true);
}

// ignore: unused_element
const _accent = AppTheme.mint;
