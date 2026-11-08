import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';
import 'media_detail_page.dart';

class ArtistDetailPage extends StatefulWidget {
  const ArtistDetailPage({super.key, required this.artist});
  final ArtistItem artist;

  @override
  State<ArtistDetailPage> createState() => _ArtistDetailPageState();
}

class _ArtistDetailPageState extends State<ArtistDetailPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final List<MusicItem> _songs = [];
  final List<AlbumItem> _albums = [];
  int _page = 0;
  bool _loading = false;
  bool _ended = false;
  String? _error;
  bool _descExpanded = false;
  int _tabIndex = 0;

  PluginRecord? get _plugin => PluginManager.instance.byPlatform(widget.artist.platform);

  @override
  void initState() {
    super.initState();
    _tab.addListener(() {
      if (_tab.index != _tabIndex) {
        setState(() => _tabIndex = _tab.index);
        if (_tab.index == 0 && _songs.isEmpty) {
          _page = 0;
          _ended = false;
          _load();
        } else if (_tab.index == 1 && _albums.isEmpty) {
          _page = 0;
          _ended = false;
          _load();
        }
      }
    });
    _load();
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
      final type = _tabIndex == 0 ? 'music' : 'album';
      final res = await PluginManager.instance.getArtistWorks(plugin, widget.artist, _page + 1, type);
      if (res == null) {
        setState(() => _error = '获取失败');
      } else {
        final data = res['data'] ?? res['musicList'] ?? res['entries'];
        if (data is List) {
          if (type == 'music') {
            final existing = _songs.map((e) => e.key).toSet();
            for (final raw in data.whereType<Map>()) {
              final song = MusicItem.fromJson(Map<String, dynamic>.from(raw));
              if (!existing.contains(song.key)) {
                _songs.add(song);
                existing.add(song.key);
              }
            }
          } else {
            final existing = _albums.map((e) => e.key).toSet();
            for (final raw in data.whereType<Map>()) {
              final album = AlbumItem.fromJson(Map<String, dynamic>.from(raw));
              if (!existing.contains(album.key)) {
                _albums.add(album);
                existing.add(album.key);
              }
            }
          }
        }
        _page += 1;
        _ended = res['isEnd'] == true || (data is List && data.isEmpty);
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                artist: artist,
                descExpanded: _descExpanded,
                onToggleDesc: () => setState(() => _descExpanded = !_descExpanded),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tab,
                tabs: [Tab(text: t('单曲')), Tab(text: t('专辑'))],
                labelColor: Theme.of(context).colorScheme.primary,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
              Theme.of(context).colorScheme.surface,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _buildMusic(),
            _buildAlbums(),
          ],
        ),
      ),
    );
  }

  Widget _buildMusic() {
    if (_songs.isEmpty && _loading) return const LoadingView();
    if (_songs.isEmpty) {
      return EmptyView(
        icon: Icons.music_off_rounded,
        text: _error ?? '没有获取到作品',
        action: _error == null ? null : _load,
        actionLabel: '重试',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 40),
      itemCount: _songs.length + 1,
      itemBuilder: (context, i) {
        if (i == _songs.length) {
          return _footer();
        }
        final song = _songs[i];
        return MusicTile(
          song: song,
          index: i,
          onTap: () => PlayerService.instance.playQueue(_songs, startIndex: i),
          onMore: () => showSongActions(context, song),
        );
      },
    );
  }

  Widget _buildAlbums() {
    if (_albums.isEmpty && _loading) return const LoadingView();
    if (_albums.isEmpty) {
      return EmptyView(icon: Icons.album_outlined, text: _error ?? '没有获取到专辑');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      itemCount: _albums.length + 1,
      itemBuilder: (context, i) {
        if (i == _albums.length) return _footer();
        final album = _albums[i];
        return ListTile(
          leading: CoverImage(path: album.artwork, size: 52, radius: 12),
          title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [album.date, album.worksNum > 0 ? '${album.worksNum} 首' : ''].where((e) => e.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
          ),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MusicListDetailPage(
              title: album.title,
              artwork: album.artwork,
              subtitle: album.artist,
              description: album.description,
              album: album,
              kind: MediaListKind.album,
            ),
          )),
        );
      },
    );
  }

  Widget _footer() {
    if (_loading) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (_ended) return Padding(padding: const EdgeInsets.all(16), child: Center(child: Tr('没有更多了', style: TextStyle(fontSize: 12, color: AppPalette.muted(context)))));
    return Padding(padding: const EdgeInsets.all(12), child: OutlinedButton(onPressed: _load, child: const Tr('加载更多')));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.artist, required this.descExpanded, required this.onToggleDesc});
  final ArtistItem artist;
  final bool descExpanded;
  final VoidCallback onToggleDesc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              ClipOval(child: CoverImage(path: artist.avatar, size: 92, radius: 46)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      [if (artist.fans > 0) '${_fans(artist.fans)} 粉丝', if (artist.worksNum > 0) '${artist.worksNum} 作品'].join(' · '),
                      style: TextStyle(fontSize: 12, color: AppPalette.muted(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (artist.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onToggleDesc,
              child: Text(
                artist.description,
                maxLines: descExpanded ? 6 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.5, color: AppPalette.muted(context)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fans(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    return '$n';
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar, this.color);
  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: color, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
