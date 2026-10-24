import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

class SearchPage extends StatefulWidget {
  final String initialQuery;
  const SearchPage({super.key, this.initialQuery = ''});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const hot = [
    '周杰伦', '林俊杰', '邓紫棋', '陈奕迅', '薛之谦', '华语流行',
    '深夜电台', '说唱', '纯音乐', '粤语经典', '轻音乐', '摇滚',
  ];

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<Song> _songs = [];
  final List<Playlist> _playlists = [];
  String _query = '';
  int _tab = 0;
  int _page = 1;
  bool _loading = false;
  bool _more = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _controller.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.initialQuery));
    }
    _scroll.addListener(() {
      if (_tab == 0 &&
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 400 &&
          !_loading &&
          _more &&
          _query.isNotEmpty) {
        _search(_query, more: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _search(String kw, {bool more = false}) async {
    final query = kw.trim();
    if (query.isEmpty) return;
    if (!more) {
      setState(() {
        _query = query;
        _songs.clear();
        _playlists.clear();
        _page = 1;
        _more = true;
        _error = null;
      });
    }
    setState(() => _loading = true);
    try {
      final api = context.read<KgApi>();
      if (_tab == 0) {
        final list = await api.searchSongs(query, page: _page, pageSize: 30);
        if (!mounted) return;
        setState(() {
          _songs.addAll(list);
          _page++;
          _more = list.length >= 30;
          _loading = false;
        });
      } else {
        final list = await api.searchPlaylists(query, page: 1, pageSize: 30);
        if (!mounted) return;
        setState(() {
          _playlists
            ..clear()
            ..addAll(list);
          _loading = false;
          _more = false;
        });
      }
      if (mounted) context.read<SettingsModel>().addSearchHistory(query);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KgException ? e.message : '搜索失败，请稍后再试';
      });
    }
  }

  void _switchTab(int tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    if (_query.isNotEmpty) _search(_query);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialQuery.isEmpty,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _search(v),
            decoration: InputDecoration(
              hintText: '搜索歌曲、歌手、歌单',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _songs.clear();
                          _playlists.clear();
                        });
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _search(_controller.text),
            child: const Text('搜索', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: _query.isEmpty
          ? _buildSuggestions(context)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      _Segmented(
                        labels: const ['单曲', '歌单'],
                        index: _tab,
                        onChanged: _switchTab,
                      ),
                      const Spacer(),
                      Text('“$_query” 的结果',
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                ),
                Expanded(
                  child: _tab == 0 ? _songResults() : _playlistResults(),
                ),
              ],
            ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        if (settings.searchHistory.isNotEmpty) ...[
          Row(
            children: [
              const Text('最近搜索',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: settings.clearSearchHistory,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: scheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in settings.searchHistory)
                ActionChip(
                  label: Text(h),
                  onPressed: () {
                    _controller.text = h;
                    _search(h);
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const Text('大家都在搜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < hot.length; i++)
              ActionChip(
                avatar: i < 3
                    ? Icon(Icons.local_fire_department_rounded,
                        size: 15, color: scheme.primary)
                    : null,
                label: Text(hot[i]),
                onPressed: () {
                  _controller.text = hot[i];
                  _search(hot[i]);
                },
              ),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '小提示：听过的歌曲会自动缓存到本地，断网也能继续播放。',
                  style: TextStyle(
                      fontSize: 12, height: 1.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _songResults() {
    if (_songs.isEmpty && _loading) return const LoadingView(label: '正在搜索…');
    if (_songs.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: () => _search(_query));
    if (_songs.isEmpty) {
      return const EmptyView(
          icon: Icons.search_off_rounded, title: '没有找到相关歌曲', subtitle: '换个关键词试试');
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: _songs.length + 1,
      itemBuilder: (context, i) {
        if (i == _songs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_more ? '' : '没有更多了',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
            ),
          );
        }
        final s = _songs[i];
        return SongTile(
          song: s,
          index: i,
          onTap: () => playSongList(context, _songs, i),
          onMore: () => openSongMenu(context, s),
          trailing: IconButton(
            onPressed: () {
              context.read<PlayerController>().appendToQueue(s);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已加入播放队列')));
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }

  Widget _playlistResults() {
    if (_playlists.isEmpty && _loading) return const LoadingView(label: '正在搜索歌单…');
    if (_playlists.isEmpty && _error != null) return ErrorView(message: _error!);
    if (_playlists.isEmpty) {
      return const EmptyView(
          icon: Icons.playlist_remove_rounded, title: '没有找到相关歌单', subtitle: '换个关键词试试');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cols = width > 1000 ? 5 : width > 720 ? 4 : width > 520 ? 3 : 2;
        final item = (width - 40 - (cols - 1) * 14) / cols;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 20,
            childAspectRatio: item / (item + 52),
          ),
          itemCount: _playlists.length,
          itemBuilder: (_, i) {
            final p = _playlists[i];
            return InkWell(
              onTap: () => Navigator.pushNamed(context, '/playlist',
                  arguments: {'id': p.id, 'name': p.name}),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoverArt(url: p.coverUrl, size: item, radius: 20, seed: p.name.hashCode),
                  const SizedBox(height: 8),
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, height: 1.28)),
                  Text('${p.creator} · ${formatCount(p.playCount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const _Segmented({required this.labels, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: index == i ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: index == i
                            ? scheme.onPrimary
                            : scheme.onSurface.withValues(alpha: 0.55))),
              ),
            ),
        ],
      ),
    );
  }
}
