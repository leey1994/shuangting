import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/download_service.dart';
import '../../core/library_store.dart';
import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';

enum MediaListKind { sheet, topList, album, localPlaylist }

class MusicListDetailPage extends StatefulWidget {
  const MusicListDetailPage({
    super.key,
    required this.title,
    required this.artwork,
    this.subtitle = '',
    this.description = '',
    this.sheet,
    this.album,
    this.playlist,
    required this.kind,
  });

  final String title;
  final String artwork;
  final String subtitle;
  final String description;
  final SheetItem? sheet;
  final AlbumItem? album;
  final Playlist? playlist;
  final MediaListKind kind;

  @override
  State<MusicListDetailPage> createState() => _MusicListDetailPageState();
}

class _MusicListDetailPageState extends State<MusicListDetailPage> {
  final List<MusicItem> _songs = [];
  int _page = 0;
  bool _loading = false;
  bool _ended = false;
  String? _error;
  String _description = '';
  bool _expanded = false;

  Playlist? get _playlist => widget.playlist;
  PluginRecord? get _plugin {
    final platform = widget.sheet?.platform ?? widget.album?.platform ?? '';
    return PluginManager.instance.byPlatform(platform);
  }

  @override
  void initState() {
    super.initState();
    _description = widget.description;
    if (widget.kind == MediaListKind.localPlaylist && _playlist != null) {
      _songs.addAll(_playlist!.songs);
      _ended = true;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading || _ended) return;
    final plugin = _plugin;
    if (plugin == null) {
      setState(() => _error = '插件不可用');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nextPage = _page + 1;
      Map<String, dynamic>? res;
      switch (widget.kind) {
        case MediaListKind.sheet:
          res = await PluginManager.instance.getMusicSheetInfo(plugin, widget.sheet!, nextPage);
          break;
        case MediaListKind.topList:
          res = await PluginManager.instance.getTopListDetail(plugin, widget.sheet!, nextPage);
          break;
        case MediaListKind.album:
          res = await PluginManager.instance.getAlbumInfo(plugin, widget.album!, nextPage);
          break;
        case MediaListKind.localPlaylist:
          break;
      }
      if (res == null) {
        setState(() => _error = '获取失败');
      } else {
        final list = res['musicList'] ?? res['data'] ?? res['entries'];
        if (list is List) {
          final existing = _songs.map((e) => e.key).toSet();
          for (final raw in list.whereType<Map>()) {
            final song = MusicItem.fromJson(Map<String, dynamic>.from(raw));
            if (!existing.contains(song.key)) {
              _songs.add(song);
              existing.add(song.key);
            }
          }
        }
        final info = res['albumItem'] ?? res['sheetItem'] ?? res['topListItem'];
        if (info is Map && _description.isEmpty) {
          _description = (info['description'] ?? '').toString();
        }
        _page = nextPage;
        _ended = res['isEnd'] == true || (list is List && list.isEmpty);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_songs.isEmpty) return;
    final service = PlayerService.instance;
    if (shuffle) {
      service.setMode(PlayMode.shuffle);
      service.playQueue(_songs, startIndex: 0);
    } else {
      service.playQueue(_songs, startIndex: 0);
    }
  }

  Future<void> _addAll() async {
    if (_songs.isEmpty) return;
    final lib = LibraryStore.instance;
    final choice = await showModalBottomSheet<Playlist>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Tr('添加到歌单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            for (final p in [lib.favorites, ...lib.userPlaylists])
              ListTile(
                leading: CoverImage(path: p.cover, size: 42, radius: 10),
                title: Text(p.name),
                subtitle: Text('${p.songs.length} 首', style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      final added = await lib.addSongsToPlaylist(choice, _songs);
      if (mounted) showToast(context, '已添加 $added 首到「${choice.name}」');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocal = widget.kind == MediaListKind.localPlaylist;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (isLocal && _playlist != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'rename') {
                  final name = await promptText(context, title: '重命名歌单', initial: _playlist!.name);
                  if (name != null && name.trim().isNotEmpty) {
                    await LibraryStore.instance.renamePlaylist(_playlist!, name.trim());
                    if (mounted) setState(() {});
                  }
                } else if (value == 'delete') {
                  if (await confirmDialog(context, '删除歌单「${_playlist!.name}」？')) {
                    await LibraryStore.instance.deletePlaylist(_playlist!);
                    if (mounted) Navigator.pop(context);
                  }
                } else if (value == 'clear') {
                  if (await confirmDialog(context, '清空歌单？')) {
                    await LibraryStore.instance.clearPlaylist(_playlist!);
                    if (mounted) setState(() => _songs.clear());
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'clear', child: Tr('清空')),
                PopupMenuItem(value: 'delete', child: Text('删除歌单')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: isLocal ? () async {} : _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                title: widget.title,
                artwork: widget.artwork,
                subtitle: widget.subtitle,
                description: _description,
                expanded: _expanded,
                count: _songs.length,
                onToggleDescription: () => setState(() => _expanded = !_expanded),
                onPlay: () => _playAll(),
                onShuffle: () => _playAll(shuffle: true),
                onDownload: _songs.isEmpty
                    ? null
                    : () {
                        DownloadService.instance.enqueueAll(_songs);
                        showToast(context, '已加入下载队列');
                      },
                onAdd: _songs.isEmpty ? null : _addAll,
                isLocal: isLocal,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Text(_error!, style: TextStyle(color: AppPalette.muted(context))),
                      TextButton(onPressed: _load, child: const Tr('重试')),
                    ],
                  ),
                ),
              ),
            SliverList.builder(
              itemCount: _songs.length,
              itemBuilder: (context, i) => MusicTile(
                song: _songs[i],
                index: i,
                onTap: () => PlayerService.instance.playQueue(_songs, startIndex: i),
                onMore: () => showSongActions(
                  context,
                  _songs[i],
                  onRemoved: isLocal
                      ? () async {
                          await LibraryStore.instance.removeSongAt(_playlist!, i);
                          setState(() => _songs.removeAt(i));
                        }
                      : null,
                  removeLabel: isLocal ? '从歌单移除' : null,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                    : !_ended && !isLocal
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton(onPressed: _load, child: const Tr('加载更多')),
                          )
                        : _songs.isNotEmpty && !isLocal
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: Tr('没有更多了', style: TextStyle(fontSize: 12, color: AppPalette.muted(context)))),
                              )
                            : _songs.isEmpty && !_loading
                                ? const EmptyView(text: '这里还没有歌曲', icon: Icons.music_off_rounded)
                                : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.artwork,
    required this.subtitle,
    required this.description,
    required this.expanded,
    required this.count,
    required this.onToggleDescription,
    required this.onPlay,
    required this.onShuffle,
    required this.onDownload,
    required this.onAdd,
    required this.isLocal,
  });

  final String title;
  final String artwork;
  final String subtitle;
  final String description;
  final bool expanded;
  final int count;
  final VoidCallback onToggleDescription;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;
  final VoidCallback? onDownload;
  final VoidCallback? onAdd;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(path: artwork, size: 132, radius: 22),
              const SizedBox(width: 16),
              Expanded(
                child: SizedBox(
                  height: 132,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                      const SizedBox(height: 6),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                      const SizedBox(height: 4),
                      Text('${count > 0 ? '$count 首' : '歌单'}${isLocal ? ' · 本地' : ''}', style: TextStyle(fontSize: 11, color: AppPalette.muted(context))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onToggleDescription,
              child: Text(
                description,
                maxLines: expanded ? null : 2,
                overflow: expanded ? null : TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.5, color: AppPalette.muted(context)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: count == 0 ? null : onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Tr('播放全部', style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RoundAction(icon: Icons.shuffle_rounded, onTap: count == 0 ? null : onShuffle),
              _RoundAction(icon: Icons.download_rounded, onTap: onDownload),
              _RoundAction(icon: Icons.playlist_add_rounded, onTap: onAdd),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          padding: const EdgeInsets.all(12),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
    );
  }
}
