import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

class ChartsPage extends StatefulWidget {
  final bool embedded;
  const ChartsPage({super.key, this.embedded = false});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> with AutomaticKeepAliveClientMixin {
  List<RankInfo> _ranks = [];
  bool _loading = true;
  String? _error;
  bool _grid = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ranks = await context.read<KgApi>().ranks();
      if (!mounted) return;
      setState(() {
        _ranks = ranks;
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

  void _open(RankInfo r) {
    Navigator.pushNamed(context, '/rank',
        arguments: {'id': r.id, 'name': r.name, 'cover': r.cover, 'update': r.updateFrequency});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final content = RefreshIndicator(
      onRefresh: _load,
      edgeOffset: 30,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, widget.embedded ? 20 : 8, 20, 170),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('排行榜',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    SizedBox(height: 3),
                    Text('实时热度，每天刷新', style: TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _grid = !_grid),
                style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHighest),
                icon: Icon(_grid ? Icons.view_agenda_rounded : Icons.grid_view_rounded),
                tooltip: _grid ? '列表模式' : '网格模式',
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(height: 400, child: LoadingView())
          else if (_error != null)
            SizedBox(height: 400, child: ErrorView(message: _error!, onRetry: _load))
          else if (_grid)
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth > 980
                    ? 5
                    : constraints.maxWidth > 720
                        ? 4
                        : constraints.maxWidth > 520
                            ? 3
                            : 2;
                final item = (constraints.maxWidth - (cols - 1) * 14) / cols;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: item / (item + 62),
                  ),
                  itemCount: _ranks.length,
                  itemBuilder: (_, i) {
                    final r = _ranks[i];
                    return InkWell(
                      onTap: () => _open(r),
                      borderRadius: BorderRadius.circular(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              CoverArt(
                                  url: r.coverUrl,
                                  size: item,
                                  radius: 22,
                                  seed: r.name.hashCode),
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text('TOP ${i + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.6)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(r.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(r.updateFrequency,
                              style: TextStyle(
                                  fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.4))),
                        ],
                      ),
                    );
                  },
                );
              },
            )
          else
            ...List.generate(_ranks.length, (i) {
              final r = _ranks[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _open(r),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        CoverArt(
                            url: r.coverUrl, size: 62, radius: 16, seed: r.name.hashCode),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.name,
                                  style: const TextStyle(
                                      fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('${r.updateFrequency} · ${formatCount(r.playCount)} 次播放',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurface.withValues(alpha: 0.42))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: scheme.onSurface.withValues(alpha: 0.35)),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('排行榜')),
      body: content,
    );
  }
}

class RankDetailPage extends StatefulWidget {
  final int id;
  final String name;
  final String cover;
  final String update;
  const RankDetailPage({
    super.key,
    required this.id,
    required this.name,
    this.cover = '',
    this.update = '',
  });

  @override
  State<RankDetailPage> createState() => _RankDetailPageState();
}

class _RankDetailPageState extends State<RankDetailPage> {
  final List<Song> _songs = [];
  final ScrollController _scroll = ScrollController();
  int _page = 1;
  bool _loading = true;
  bool _more = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500 &&
          !_loading &&
          _more) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (!_more && _page > 1) return;
    setState(() => _loading = true);
    try {
      final list = await context.read<KgApi>().rankSongs(widget.id, page: _page, pageSize: 40);
      if (!mounted) return;
      setState(() {
        _songs.addAll(list);
        _loading = false;
        _page++;
        _more = list.length >= 40;
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

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppTheme.coverGradient(widget.name.hashCode, isDark: isDark);
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: scheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.first.withValues(alpha: 0.65), scheme.surface],
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
                              url: widget.cover,
                              size: 116,
                              radius: 24,
                              seed: widget.name.hashCode),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(widget.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5)),
                                const SizedBox(height: 4),
                                Text(widget.update,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurface.withValues(alpha: 0.55))),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _songs.isEmpty
                                      ? null
                                      : () => playSongList(context, _songs, 0),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('播放全部'),
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
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == _songs.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: _loading
                        ? const Center(
                            child: SizedBox(
                                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                        : _error != null
                            ? Center(
                                child: TextButton(
                                    onPressed: () {
                                      setState(() => _more = true);
                                      _load();
                                    },
                                    child: Text(_error!)))
                            : const SizedBox.shrink(),
                  );
                }
                final s = _songs[i];
                return SongTile(
                  song: s,
                  index: i,
                  showIndex: true,
                  onTap: () => playSongList(context, _songs, i),
                  onMore: () => openSongMenu(context, s),
                  trailing: IconButton(
                    onPressed: () {
                      final p = context.read<PlayerController>();
                      p.appendToQueue(s);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('已加入播放队列')));
                    },
                    icon: Icon(Icons.add_rounded,
                        size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
                  ),
                );
              },
              childCount: _songs.length + 1,
            ),
          ),
        ],
      ),
    );
  }
}
