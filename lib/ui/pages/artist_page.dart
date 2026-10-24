import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/kg_api.dart';
import '../../data/models.dart';
import '../../player/player_controller.dart';
import '../widgets/common.dart';

class ArtistPage extends StatefulWidget {
  final int id;
  final String name;
  const ArtistPage({super.key, required this.id, this.name = ''});

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final List<Song> _songs = [];
  final ScrollController _scroll = ScrollController();
  ArtistInfo? _info;
  int _page = 1;
  bool _loading = true;
  bool _more = true;
  bool _expanded = false;
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
      final info = await context.read<KgApi>().artistInfo(widget.id);
      if (mounted) setState(() => _info = info);
    } catch (_) {}
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<KgApi>().artistSongs(widget.id, page: _page, pageSize: 40);
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
            expandedHeight: 360,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.first.withValues(alpha: 0.7),
                          colors.last.withValues(alpha: 0.35),
                          scheme.surface,
                        ],
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
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2), width: 2),
                                ),
                                child: ClipOval(
                                  child: CoverArt(
                                    url: _info?.avatarUrl ?? '',
                                    size: 112,
                                    radius: 56,
                                    seed: title.hashCode,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('ARTIST',
                                        style: TextStyle(
                                            fontSize: 9,
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 26, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 5),
                                    Text('${formatCount(_info?.songCount ?? 0)} 首作品',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: scheme.onSurface.withValues(alpha: 0.55))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if ((_info?.intro ?? '').isNotEmpty) ...[
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => setState(() => _expanded = !_expanded),
                              child: Text(
                                _info!.intro,
                                maxLines: _expanded ? 8 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.55,
                                    color: scheme.onSurface.withValues(alpha: 0.55)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed:
                                    _songs.isEmpty ? null : () => playSongList(context, _songs, 0),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('播放热门'),
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
