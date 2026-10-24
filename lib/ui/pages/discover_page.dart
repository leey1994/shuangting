import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../widgets/common.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  static const categories = ['推荐', '华语', '流行', '摇滚', '民谣', '电子', '说唱', '古风', '轻音乐', '粤语', '欧美'];
  static const scenes = [
    ('通勤路上', Icons.directions_subway_rounded, Color(0xFF7B5CFF)),
    ('深夜电台', Icons.nightlight_round, Color(0xFF3AA0FF)),
    ('专注学习', Icons.menu_book_rounded, Color(0xFF35D6A4)),
    ('运动燃脂', Icons.fitness_center_rounded, Color(0xFFFF4D6D)),
    ('周末咖啡', Icons.coffee_rounded, Color(0xFFFFA62B)),
    ('公路旅行', Icons.landscape_rounded, Color(0xFFF25C9C)),
  ];

  String _category = '推荐';
  List<Playlist> _playlists = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<KgApi>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final keyword = _category == '推荐' ? '热歌' : _category;
      final list = await api.searchPlaylists(keyword, pageSize: 24);
      if (!mounted) return;
      setState(() {
        _playlists = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KgException ? e.message : '加载失败';
      });
    }
  }

  void _selectCategory(String c) {
    if (_category == c) return;
    setState(() => _category = c);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      edgeOffset: 40,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('发现',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                        SizedBox(height: 3),
                        Text('跳出算法，遇见新的声音',
                            style: TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/search'),
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                itemCount: scenes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final s = scenes[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => CategoryPage(keyword: s.$1))),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            s.$3.withValues(alpha: 0.85),
                            s.$3.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(s.$2, color: Colors.white, size: 26),
                          const Spacer(),
                          Text(s.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('场景歌单',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7), fontSize: 10.5)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 0, 0),
              child: SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 20),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = categories[i];
                    final active = c == _category;
                    return ChoiceChip(
                      selected: active,
                      onSelected: (_) => _selectCategory(c),
                      showCheckmark: false,
                      label: Text(c),
                      labelStyle: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? scheme.onPrimary : scheme.onSurface.withValues(alpha: 0.65),
                      ),
                      selectedColor: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                      side: BorderSide.none,
                    );
                  },
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: LoadingView())
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(message: _error!, onRetry: _load),
            )
          else if (_playlists.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(title: '这个分类还没有歌单', subtitle: '换一个分类试试'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 170),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final cols = width > 1000 ? 5 : width > 720 ? 4 : width > 520 ? 3 : 2;
                  final item = (width - (cols - 1) * 14) / cols;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 14,
                      childAspectRatio: item / (item + 52),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _PlaylistGridCard(playlist: _playlists[i], size: item),
                      childCount: _playlists.length,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaylistGridCard extends StatelessWidget {
  final Playlist playlist;
  final double size;
  const _PlaylistGridCard({required this.playlist, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/playlist',
          arguments: {'id': playlist.id, 'name': playlist.name}),
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CoverArt(url: playlist.coverUrl, size: size, radius: 20, seed: playlist.name.hashCode),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
                      Text(formatCount(playlist.playCount),
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.28)),
          const SizedBox(height: 2),
          Text('${playlist.creator} · ${playlist.songCount} 首',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }
}

class CategoryPage extends StatefulWidget {
  final String keyword;
  const CategoryPage({super.key, required this.keyword});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Playlist> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<KgApi>().searchPlaylists(widget.keyword, pageSize: 30);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KgException ? e.message : '加载失败';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.keyword)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final cols = width > 1000 ? 5 : width > 720 ? 4 : width > 520 ? 3 : 2;
                    final item = (width - 40 - (cols - 1) * 14) / cols;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 14,
                        childAspectRatio: item / (item + 52),
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _PlaylistGridCard(playlist: _items[i], size: item),
                    );
                  },
                ),
    );
  }
}
