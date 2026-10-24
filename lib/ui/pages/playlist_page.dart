import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

class PlaylistPage extends StatefulWidget {
  final int id;
  final String name;
  const PlaylistPage({super.key, required this.id, this.name = ''});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  final List<Song> _songs = [];
  final ScrollController _scroll = ScrollController();
  Playlist? _info;
  int _page = 1;
  bool _loading = true;
  bool _more = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _loadSongs();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500 &&
          !_loading &&
          _more) {
        _loadSongs();
      }
    });
  }

  Future<void> _loadInfo() async {
    try {
      final info = await context.read<KgApi>().playlistInfo(widget.id);
      if (mounted) setState(() => _info = info);
    } catch (_) {}
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<KgApi>().playlistSongs(widget.id, page: _page, pageSize: 40);
      if (!mounted) return;
      setState(() {
        _songs.addAll(list);
        _page++;
        _more = list.length >= 40;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KgException ? e.message : '加载失败';
      });
    }
  }

  Future<void> _saveToLibrary() async {
    final library = context.read<LibraryModel>();
    final name = _info?.name ?? widget.name;
    await library.createPlaylist(name.isEmpty ? '收藏的歌单' : name, _songs);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存到自建歌单')));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _info?.name ?? widget.name;
    final colors = AppTheme.coverGradient(title.hashCode, isDark: isDark);
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            actions: [
              IconButton(
                onPressed: _songs.isEmpty ? null : _saveToLibrary,
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: '保存到音乐库',
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
                        colors: [colors.first.withValues(alpha: 0.6), scheme.surface],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CoverArt(
                                  url: _info?.coverUrl ?? '',
                                  size: 108,
                                  radius: 22,
                                  seed: title.hashCode),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                            height: 1.2)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_info?.creator ?? ''}${(_info?.songCount ?? 0) > 0 ? ' · ${_info!.songCount} 首' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: scheme.onSurface.withValues(alpha: 0.55)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if ((_info?.intro ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(_info!.intro,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: scheme.onSurface.withValues(alpha: 0.5))),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: _songs.isEmpty ? null : () => playSongList(context, _songs, 0),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('播放全部'),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                onPressed: _songs.isEmpty
                                    ? null
                                    : () {
                                        final player = context.read<PlayerController>();
                                        if (!player.shuffle) player.toggleShuffle();
                                        playSongList(context, _songs, 0);
                                      },
                                icon: const Icon(Icons.shuffle_rounded, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == _songs.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : _error != null
                              ? TextButton(
                                  onPressed: () {
                                    setState(() => _more = true);
                                    _loadSongs();
                                  },
                                  child: Text(_error!))
                              : Text('共 ${_songs.length} 首',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withValues(alpha: 0.3))),
                    ),
                  );
                }
                final s = _songs[i];
                return SongTile(
                  song: s,
                  index: i,
                  showIndex: true,
                  onTap: () => playSongList(context, _songs, i),
                  onMore: () => openSongMenu(context, s),
                );
              },
              childCount: _songs.length + 1,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ],
      ),
    );
  }
}

class AlbumPage extends StatefulWidget {
  final int id;
  final String name;
  const AlbumPage({super.key, required this.id, this.name = ''});

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends State<AlbumPage> {
  final List<Song> _songs = [];
  AlbumInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<KgApi>();
      final info = await api.albumInfo(widget.id);
      final songs = await api.albumSongs(widget.id, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _info = info;
        _songs
          ..clear()
          ..addAll(songs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KgException ? e.message : '专辑加载失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _info?.name ?? widget.name;
    final colors = AppTheme.coverGradient(title.hashCode, isDark: isDark);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.last.withValues(alpha: 0.6), scheme.surface],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              CoverArt(
                                  url: _info?.coverUrl ?? '',
                                  size: 108,
                                  radius: 22,
                                  seed: title.hashCode),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('ALBUM',
                                        style: TextStyle(
                                            fontSize: 9,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            height: 1.2)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${_info?.artist ?? ''}${(_info?.publishTime ?? '').isNotEmpty ? ' · ${_info!.publishTime.split(' ').first}' : ''}',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: scheme.onSurface.withValues(alpha: 0.55)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _songs.isEmpty ? null : () => playSongList(context, _songs, 0),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('播放专辑'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: LoadingView())
          else if (_error != null)
            SliverFillRemaining(
                hasScrollBody: false, child: ErrorView(message: _error!, onRetry: _load))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = _songs[i];
                  return SongTile(
                    song: s,
                    index: i,
                    showIndex: true,
                    onTap: () => playSongList(context, _songs, i),
                    onMore: () => openSongMenu(context, s),
                  );
                },
                childCount: _songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 130)),
        ],
      ),
    );
  }
}
