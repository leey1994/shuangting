import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

class HomeData {
  final List<RankInfo> ranks;
  final List<Playlist> playlists;
  final List<Song> hot;
  final List<Song> fresh;
  const HomeData({
    required this.ranks,
    required this.playlists,
    required this.hot,
    required this.fresh,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  HomeData? _data;
  String? _error;
  bool _loading = true;

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
      final ranks = await api.ranks();
      final hot = await api.rankSongs(6666, pageSize: 8);
      final fresh = await api.rankSongs(74534, pageSize: 6);
      final playlists = <Playlist>[];
      for (final kw in ['华语流行', '深夜电台', '通勤路上']) {
        try {
          final p = await api.searchPlaylists(kw, pageSize: 6);
          playlists.addAll(p);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _data = HomeData(ranks: ranks, playlists: playlists, hot: hot, fresh: fresh);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is KgException ? e.message : '加载失败，请检查网络';
      });
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 11) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      edgeOffset: 40,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 170),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting,
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(height: 3),
                      const Text('今天想听点什么？',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/search'),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded,
                        size: 20, color: scheme.onSurface.withValues(alpha: 0.4)),
                    const SizedBox(width: 10),
                    Text('搜索歌曲、歌手、歌单',
                        style: TextStyle(
                            fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.4))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('发现',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading && data == null)
            const Padding(padding: EdgeInsets.only(top: 80), child: LoadingView())
          else if (_error != null && data == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: ErrorView(message: _error!, onRetry: _load),
            )
          else if (data != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: _HeroBanner(data: data),
            ),
            _QuickActions(),
            SectionHeader(
              title: '为你精选',
              subtitle: '根据此刻的心情挑选',
              action: '换一批',
              onAction: _load,
            ),
            SizedBox(
              height: 226,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: data.playlists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final p = data.playlists[i];
                  return _PlaylistCard(playlist: p);
                },
              ),
            ),
            SectionHeader(
              title: '热歌速递',
              subtitle: '此刻大家都在听',
              action: '查看榜单',
              onAction: () => Navigator.pushNamed(context, '/charts'),
            ),
            if (data.hot.isNotEmpty)
              ...List.generate(data.hot.length, (i) {
                final s = data.hot[i];
                return SongTile(
                  song: s,
                  index: i,
                  showIndex: true,
                  onTap: () => playSongList(context, data.hot, i),
                  onMore: () => openSongMenu(context, s),
                );
              }),
            SectionHeader(
              title: '排行榜',
              subtitle: '每天更新，跟上热度',
              action: '全部',
              onAction: () => Navigator.pushNamed(context, '/charts'),
            ),
            SizedBox(
              height: 176,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: data.ranks.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final r = data.ranks[i];
                  return _RankCard(rank: r);
                },
              ),
            ),
            SectionHeader(
              title: '新歌上架',
              subtitle: '刚刚抵达爽听',
              action: '试听',
              onAction: data.fresh.isEmpty ? null : () => playSongList(context, data.fresh, 0),
            ),
            if (data.fresh.isNotEmpty)
              ...List.generate(data.fresh.length, (i) {
                final s = data.fresh[i];
                return SongTile(
                  song: s,
                  index: i,
                  showIndex: true,
                  onTap: () => playSongList(context, data.fresh, i),
                  onMore: () => openSongMenu(context, s),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final HomeData data;
  const _HeroBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final songs = data.hot.take(3).toList();
    final first = songs.isNotEmpty ? songs.first : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.85),
                    const Color(0xFF7B5CFF).withValues(alpha: 0.75),
                    const Color(0xFF101420),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.mint.withValues(alpha: 0.5),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('DAILY MIX · 每日推荐',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        first?.title ?? '把喜欢的歌\n装进口袋',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        first == null ? '离线缓存 · 随时畅听' : '${first.artist} · 为你挑选',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72), fontSize: 12),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: first == null
                                ? null
                                : () => playSongList(context, data.hot, 0),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF16121C),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: const Text('立即播放', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () {
                              final player = context.read<PlayerController>();
                              player.enterFm(() => context.read<KgApi>().rankSongs(6666, pageSize: 20));
                              Navigator.pushNamed(context, '/player');
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.16),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.radio_rounded, size: 20),
                            tooltip: '私人 FM',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (songs.isNotEmpty)
                  SizedBox(
                    width: 96,
                    height: 130,
                    child: Stack(
                      children: [
                        for (var i = 0; i < songs.length; i++)
                          Positioned(
                            left: i * 12.0,
                            top: i * 10.0,
                            child: Transform.rotate(
                              angle: (i - 1) * 0.12,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black38, blurRadius: 14)
                                  ],
                                ),
                                child: CoverArt(
                                  url: songs[i].coverUrl,
                                  size: 78,
                                  radius: 16,
                                  seed: songs[i].hash.hashCode,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();
    final player = context.read<PlayerController>();
    final api = context.read<KgApi>();
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (Icons.radio_rounded, '私人 FM', AppTheme.mint),
      (Icons.bolt_rounded, '每日推荐', scheme.primary),
      (Icons.download_done_rounded, '我的下载', const Color(0xFF7B5CFF)),
      (Icons.verified_rounded, settings.signedInToday ? '已签到' : '签到', const Color(0xFFFFA62B)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  if (i == 0) {
                    player.enterFm(() => api.rankSongs(6666, pageSize: 20));
                    Navigator.pushNamed(context, '/player');
                  } else if (i == 1) {
                    final songs = await api.rankSongs(8888, pageSize: 30);
                    if (context.mounted && songs.isNotEmpty) playSongList(context, songs, 0);
                  } else if (i == 2) {
                    Navigator.pushNamed(context, '/downloads');
                  } else {
                    if (!settings.signedInToday) {
                      await settings.signInToday();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('签到成功 · 连续 ${settings.signInStreak} 天')));
                      }
                    } else {
                      Navigator.pushNamed(context, '/about');
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    children: [
                      Icon(items[i].$1, color: items[i].$3, size: 22),
                      const SizedBox(height: 7),
                      Text(items[i].$2,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/playlist',
          arguments: {'id': playlist.id, 'name': playlist.name}),
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 154,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverArt(
                  url: playlist.coverUrl,
                  size: 154,
                  radius: 22,
                  seed: playlist.name.hashCode,
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 13),
                        Text(formatCount(playlist.playCount),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(playlist.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 3),
            Text(playlist.creator,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final RankInfo rank;
  const _RankCard({required this.rank});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/rank',
          arguments: {'id': rank.id, 'name': rank.name, 'cover': rank.cover}),
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        width: 142,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverArt(url: rank.coverUrl, size: 142, radius: 22, seed: rank.name.hashCode),
            const SizedBox(height: 8),
            Text(rank.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(rank.updateFrequency,
                style: TextStyle(
                    fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}
