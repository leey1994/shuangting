import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'media_detail_page.dart';
import 'plugin_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  /// 启动时参与聚合的音源上限，避免插件多时创建大量运行时导致白屏。
  static const _maxAggregateSources = 6;
  String? _platform;
  final Map<String, List<Map<String, dynamic>>> _topLists = {};
  final Map<String, Map<String, dynamic>> _tags = {};
  final Map<String, List<SheetItem>> _sheets = {};
  final Map<String, int> _sheetPages = {};
  final Map<String, bool> _sheetEnded = {};
  final Map<String, Map<String, dynamic>> _selectedTag = {};
  final Set<String> _loading = {};
  bool _aggregateLoading = false;
  bool _aggregateLoaded = false;
  int _aggregateGeneration = 0;
  List<_AggregateRank> _aggregateRanks = [];
  List<_AggregateSong> _aggregateSongs = [];
  final Map<String, int> _aggregateRankCounts = {};
  final Map<String, int> _aggregateSongCounts = {};
  final Set<String> _aggregateRankSeen = {};
  final Set<String> _aggregateSongSeen = {};
  bool _bootstrapping = false;
  String _pluginSignature = '';

  List<PluginRecord> get _plugins => PluginManager.instance.enabled;

  @override
  void initState() {
    super.initState();
    _pluginSignature = _currentPluginSignature();
    PluginManager.instance.addListener(_onPlugins);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  String _currentPluginSignature() => _plugins
      .map((e) => '${e.platform}:${e.enabled}')
      .join('|');

  void _onPlugins() {
    final signature = _currentPluginSignature();
    if (signature == _pluginSignature) return;
    _pluginSignature = signature;
    _aggregateLoaded = false;
    if (mounted) _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapping) return;
    _bootstrapping = true;
    try {
      await PluginManager.instance.warmup(limit: 2);
      final plugins = _plugins;
      if (plugins.isEmpty) return;
      if (_platform == null || !plugins.any((e) => e.platform == _platform)) {
        _platform = plugins.first.platform;
      }
      unawaited(_loadAggregate());
      await _loadPlugin(plugins.firstWhere((e) => e.platform == _platform));
    } finally {
      _bootstrapping = false;
    }
  }

  @override
  void dispose() {
    _aggregateGeneration++;
    PluginManager.instance.removeListener(_onPlugins);
    super.dispose();
  }

  Future<void> _loadPlugin(PluginRecord plugin) async {
    if (_loading.contains(plugin.platform)) return;
    _loading.add(plugin.platform);
    if (mounted) setState(() {});

    try {
      await PluginManager.instance.runtimeFor(plugin);
      if (!_topLists.containsKey(plugin.platform) && plugin.methods.contains('getTopLists')) {
        final lists = await PluginManager.instance.getTopLists(plugin);
        _topLists[plugin.platform] = lists.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (!_tags.containsKey(plugin.platform) && plugin.methods.contains('getRecommendSheetTags')) {
        final tags = await PluginManager.instance.getRecommendSheetTags(plugin);
        if (tags != null) {
          _tags[plugin.platform] = tags;
          final tag = _firstTag(tags);
          if (tag != null) {
            _selectedTag[plugin.platform] = tag;
            await _loadSheets(plugin, tag, reset: true);
          }
        }
      }
    } catch (_) {}
    _loading.remove(plugin.platform);
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? _firstTag(Map<String, dynamic> tags) {
    final pinned = tags['pinned'];
    if (pinned is List && pinned.isNotEmpty) {
      final first = pinned.first;
      if (first is Map) return {'id': first['id'] ?? '', 'title': first['title'] ?? '推荐', ...first};
    }
    final groups = tags['data'];
    if (groups is List) {
      for (final g in groups) {
        if (g is Map && g['data'] is List && (g['data'] as List).isNotEmpty) {
          final first = (g['data'] as List).first;
          if (first is Map) return Map<String, dynamic>.from(first);
        }
      }
    }
    return null;
  }

  Future<void> _loadSheets(PluginRecord plugin, Map<String, dynamic> tag, {bool reset = false}) async {
    if (!plugin.methods.contains('getRecommendSheetsByTag')) return;
    if (reset) {
      _sheets[plugin.platform] = [];
      _sheetPages[plugin.platform] = 0;
      _sheetEnded[plugin.platform] = false;
    }
    if (_sheetEnded[plugin.platform] == true) return;
    final page = (_sheetPages[plugin.platform] ?? 0) + 1;
    final res = await PluginManager.instance.getRecommendSheetsByTag(plugin, tag, page);
    if (res == null) return;
    final data = res['data'];
    final list = _sheets.putIfAbsent(plugin.platform, () => []);
    if (data is List) {
      list.addAll(data.whereType<Map>().map((e) => SheetItem.fromJson(Map<String, dynamic>.from(e))));
    }
    _sheetPages[plugin.platform] = page;
    _sheetEnded[plugin.platform] = res['isEnd'] == true;
  }

  Future<void> _loadAggregate({bool force = false}) async {
    if (_aggregateLoading && !force) return;
    if (_aggregateLoaded && !force) return;
    final generation = ++_aggregateGeneration;
    _aggregateLoaded = false;
    if (mounted) setState(() => _aggregateLoading = true);

    await PluginManager.instance.warmup(limit: 2);
    if (generation != _aggregateGeneration) return;
    // 榜单聚合只取前 6 个音源：QuickJS 运行时创建发生在主 isolate，
    // 插件过多时逐个创建会长时间阻塞首帧（白屏），其余音源按需再拉。
    final plugins = _plugins
        .where((e) => e.methods.contains('getTopLists'))
        .take(_maxAggregateSources)
        .toList();
    if (plugins.isEmpty) {
      _aggregateRanks = [];
      _aggregateSongs = [];
      _aggregateRankCounts.clear();
      _aggregateSongCounts.clear();
      _aggregateRankSeen.clear();
      _aggregateSongSeen.clear();
      _aggregateLoaded = true;
      if (mounted) setState(() => _aggregateLoading = false);
      return;
    }

    _aggregateRankCounts.clear();
    _aggregateSongCounts.clear();
    _aggregateRankSeen.clear();
    _aggregateSongSeen.clear();

    // 首批只拉前两个音源，先让界面有内容；后续源在事件循环空档逐批补齐。
    final initial = plugins.take(2).toList();
    for (var i = 0; i < initial.length; i++) {
      await _mergeAggregatePlugin(initial[i], i < 3, generation);
      if (generation != _aggregateGeneration) return;
    }

    if (mounted) setState(() => _aggregateLoading = false);
    if (initial.length >= plugins.length) {
      _aggregateLoaded = true;
      return;
    }
    unawaited(_loadAggregateTail(plugins.skip(initial.length).toList(), initial.length, generation));
  }

  Future<void> _loadAggregateTail(
    List<PluginRecord> plugins,
    int startIndex,
    int generation,
  ) async {
    for (var i = 0; i < plugins.length; i++) {
      // 留出事件循环，避免连续 QuickJS / 网络请求让界面失去响应。
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (generation != _aggregateGeneration) return;
      await _mergeAggregatePlugin(plugins[i], startIndex + i < 3, generation);
      if (generation != _aggregateGeneration) return;
    }
    _aggregateLoaded = true;
  }

  Future<void> _mergeAggregatePlugin(PluginRecord plugin, bool withSongs, int generation) async {
    final data = await _collectPlugin(plugin, withSongs: withSongs);
    if (generation != _aggregateGeneration) return;

    for (final rank in data.ranks) {
      if (_aggregateRanks.length >= 24) break;
      final count = _aggregateRankCounts[rank.platform] ?? 0;
      if (count >= 6) continue;
      final key = '${rank.platform}|${rank.sheet.id}|${rank.sheet.title}';
      if (rank.sheet.id.isEmpty || !_aggregateRankSeen.add(key)) continue;
      _aggregateRanks.add(rank);
      _aggregateRankCounts[rank.platform] = count + 1;
    }
    for (final entry in data.songs) {
      if (_aggregateSongs.length >= 40) break;
      final count = _aggregateSongCounts[entry.source] ?? 0;
      if (count >= 6) continue;
      final key = '${entry.song.title.trim().toLowerCase()}|${entry.song.artist.trim().toLowerCase()}';
      if (entry.song.id.isEmpty || !_aggregateSongSeen.add(key)) continue;
      _aggregateSongs.add(entry);
      _aggregateSongCounts[entry.source] = count + 1;
    }
    if (mounted) setState(() {});
  }

  Future<_AggregateData> _collectPlugin(PluginRecord plugin, {bool withSongs = false}) async {
    final ranks = <_AggregateRank>[];
    final songs = <_AggregateSong>[];
    try {
      final lists = await PluginManager.instance.getTopLists(plugin);
      SheetItem? first;
      for (final item in lists) {
        if (item is! Map) continue;
        if (item['data'] is List) {
          final group = (item['title'] ?? item['name'] ?? '榜单').toString();
          for (final raw in (item['data'] as List).whereType<Map>()) {
            final map = _withPlatform(raw, plugin.platform);
            final sheet = SheetItem.fromJson(map);
            if (sheet.id.isEmpty && sheet.title.isEmpty) continue;
            ranks.add(_AggregateRank(sheet, plugin.platform, group));
            first ??= sheet;
          }
        } else if (item['id'] != null || item['title'] != null) {
          final map = _withPlatform(item, plugin.platform);
          final sheet = SheetItem.fromJson(map);
          if (sheet.id.isEmpty && sheet.title.isEmpty) continue;
          ranks.add(_AggregateRank(sheet, plugin.platform, '榜单'));
          first ??= sheet;
        }
      }
      if (withSongs && first != null && plugin.methods.contains('getTopListDetail')) {
        final detail = await PluginManager.instance.getTopListDetail(plugin, first, 1);
        final data = detail?['musicList'] ?? detail?['data'] ?? detail?['entries'];
        if (data is List) {
          for (final raw in data.whereType<Map>().take(10)) {
            final map = _withPlatform(raw, plugin.platform);
            final song = MusicItem.fromJson(map);
            if (song.id.isEmpty && song.title.isEmpty) continue;
            songs.add(_AggregateSong(song, plugin.platform));
          }
        }
      }
    } catch (_) {}
    return _AggregateData(ranks, songs);
  }

  Map<String, dynamic> _withPlatform(Map raw, String platform) {
    final map = Map<String, dynamic>.from(raw);
    if ((map['platform'] ?? '').toString().isEmpty) map['platform'] = platform;
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final plugins = _plugins;
    final selected = _platform == null ? null : PluginManager.instance.byPlatform(_platform!);
    return RefreshIndicator(
      onRefresh: () async {
        _topLists.clear();
        _tags.clear();
        _sheets.clear();
        _sheetPages.clear();
        _sheetEnded.clear();
        _selectedTag.clear();
        _aggregateRanks = [];
        _aggregateSongs = [];
        final p = selected;
        final tasks = <Future<void>>[_loadAggregate(force: true)];
        if (p != null) tasks.add(_loadPlugin(p));
        await Future.wait(tasks);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final body = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              ListenableBuilder(
                listenable: PlayerService.instance.pageListenable,
                builder: (_, _) => const _HeroHeader(),
              ),
              ..._buildAggregate(),
              if (plugins.isEmpty)
                _bootstrapping
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _InstallHint(onInstall: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginPage())))
              else ...[
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: plugins.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final p = plugins[i];
                      return TagChip(
                        label: p.platform,
                        selected: p.platform == _platform,
                        onTap: () async {
                          setState(() => _platform = p.platform);
                          await _loadPlugin(p);
                        },
                      );
                    },
                  ),
                ),
                if (selected != null) ..._buildPluginContent(selected),
              ],
              const SizedBox(height: 30),
            ],
          );
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth > 1000 ? 1080 : constraints.maxWidth),
              child: body,
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildAggregate() {
    final ranks = _aggregateRanks;
    final songs = _aggregateSongs;
    return [
      SectionTitle(
        t('聚合榜单'),
        trailing: '${ranks.length} ${t('个')}',
        onTrailing: () => _loadAggregate(force: true),
      ),
      if (_aggregateLoading && ranks.isEmpty && songs.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: LoadingView(text: '正在聚合各音源榜单'),
        ),
      if (!_aggregateLoading && ranks.isEmpty && songs.isEmpty)
        EmptyView(
          icon: Icons.leaderboard_outlined,
          text: '暂无可聚合的榜单\n安装或启用插件后下拉刷新',
        ),
      if (ranks.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.76,
            ),
            itemCount: ranks.length > 24 ? 24 : ranks.length,
            itemBuilder: (_, i) => _rankCard(ranks[i]),
          ),
        ),
      if (!_aggregateLoading && ranks.isEmpty && songs.isNotEmpty)
        const SizedBox(height: 4),
      if (songs.isNotEmpty) ...[
        SectionTitle('全源热歌', trailing: '${songs.length} ${t('首')}'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: songs.length > 30 ? 30 : songs.length,
          itemBuilder: (context, i) {
            final entry = songs[i];
            return MusicTile(
              song: entry.song,
              onTap: () => PlayerService.instance.playQueue(
                songs.map((e) => e.song).toList(),
                startIndex: i,
              ),
              trailing: Text(
                entry.source,
                style: TextStyle(fontSize: 10, color: AppPalette.muted(context)),
              ),
            );
          },
        ),
      ],
    ];
  }

  Widget _rankCard(_AggregateRank rank) {
    final sheet = rank.sheet;
    return Stack(
      children: [
        SheetGridCard(
          title: sheet.title.isEmpty ? rank.group : sheet.title,
          artwork: sheet.artwork,
          subtitle: '${rank.platform} · ${rank.group}',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MusicListDetailPage(
              title: sheet.title.isEmpty ? rank.group : sheet.title,
              artwork: sheet.artwork,
              subtitle: '${rank.platform} · ${rank.group}',
              sheet: sheet,
              kind: MediaListKind.topList,
            ),
          )),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rank.platform,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPluginContent(PluginRecord plugin) {
    final widgets = <Widget>[];
    final loading = _loading.contains(plugin.platform);
    final topLists = _topLists[plugin.platform] ?? const [];
    final tags = _tags[plugin.platform];
    final sheets = _sheets[plugin.platform] ?? const [];
    final selectedTag = _selectedTag[plugin.platform];

    if (loading && topLists.isEmpty && sheets.isEmpty) {
      return [const Padding(padding: EdgeInsets.only(top: 80), child: LoadingView(text: '正在获取推荐'))];
    }

    for (final group in topLists) {
      final title = (group['title'] ?? '排行榜').toString();
      final data = group['data'];
      if (data is! List || data.isEmpty) continue;
      widgets.add(SectionTitle(title));
      widgets.add(SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: data.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final raw = data[i];
            if (raw is! Map) return const SizedBox.shrink();
            final sheet = SheetItem.fromJson(Map<String, dynamic>.from(raw));
            return SizedBox(
              width: 124,
              child: SheetGridCard(
                title: sheet.title,
                artwork: sheet.artwork,
                subtitle: sheet.artist,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MusicListDetailPage(
                    title: sheet.title,
                    artwork: sheet.artwork,
                    subtitle: sheet.artist,
                    sheet: sheet,
                    kind: MediaListKind.topList,
                  ),
                )),
              ),
            );
          },
        ),
      ));
    }

    if (tags != null) {
      final pinned = (tags['pinned'] as List?) ?? const [];
      final groups = (tags['data'] as List?) ?? const [];
      final allTags = <Map<String, dynamic>>[
        for (final p in pinned.whereType<Map>()) Map<String, dynamic>.from(p),
        for (final g in groups.whereType<Map>())
          if (g['data'] is List)
            ...(g['data'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      ];
      if (allTags.isNotEmpty) {
        widgets.add(const SectionTitle('发现好歌单'));
        widgets.add(SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: allTags.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final tag = allTags[i];
              final id = (tag['id'] ?? tag['title'] ?? '').toString();
              final selectedId = (selectedTag?['id'] ?? selectedTag?['title'] ?? '').toString();
              return TagChip(
                label: (tag['title'] ?? tag['name'] ?? id).toString(),
                selected: id == selectedId,
                onTap: () async {
                  setState(() => _selectedTag[plugin.platform] = tag);
                  await _loadSheets(plugin, tag, reset: true);
                  if (mounted) setState(() {});
                },
              );
            },
          ),
        ));
        const SizedBox(height: 6);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.76,
            ),
            itemCount: sheets.length + (_sheetEnded[plugin.platform] == false ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == sheets.length) {
                return Center(
                  child: TextButton(
                    onPressed: () async {
                      final tag = _selectedTag[plugin.platform];
                      if (tag != null) {
                        await _loadSheets(plugin, tag);
                        if (mounted) setState(() {});
                      }
                    },
                    child: const Tr('加载更多'),
                  ),
                );
              }
              final sheet = sheets[i];
              return SheetGridCard(
                title: sheet.title,
                artwork: sheet.artwork,
                subtitle: sheet.artist.isEmpty ? '${sheet.worksNum} 首' : sheet.artist,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MusicListDetailPage(
                    title: sheet.title,
                    artwork: sheet.artwork,
                    subtitle: sheet.artist,
                    sheet: sheet,
                    kind: MediaListKind.sheet,
                  ),
                )),
              );
            },
          ),
        ));
      }
    }

    if (topLists.isEmpty && sheets.isEmpty && !loading) {
      widgets.add(EmptyView(
        icon: Icons.explore_outlined,
        text: '这个插件还没有推荐内容\n试试搜索，或者换一个插件',
        action: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginPage())),
        actionLabel: '管理插件',
      ));
    }
    return widgets;
  }
}

class _AggregateRank {
  const _AggregateRank(this.sheet, this.platform, this.group);
  final SheetItem sheet;
  final String platform;
  final String group;
}

class _AggregateSong {
  const _AggregateSong(this.song, this.source);
  final MusicItem song;
  final String source;
}

class _AggregateData {
  const _AggregateData(this.ranks, this.songs);
  final List<_AggregateRank> ranks;
  final List<_AggregateSong> songs;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深了';
    if (h < 12) return '早上好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.instance;
    final current = p.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (rect) => AppPalette.brandGradient(context).createShader(rect),
                child: const Text(
                  '爽听',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.5, height: 1),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(t('听见爽'), style: TextStyle(fontSize: 11, color: AppPalette.muted(context), letterSpacing: 2)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$_greeting，${t('今天想听点什么？')}', style: TextStyle(fontSize: 13, color: AppPalette.muted(context))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: current == null ? null : () => MiniPlayer.openPlayer(context),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppPalette.brandGradient(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (current != null) ...[
                    CoverImage(path: current.artwork, size: 56, radius: 16),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t('继续听'), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(current.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 42),
                  ] else ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('把喜欢的歌，听到爽', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(height: 4),
                          Text('安装插件，连接你的音乐世界', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 34),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallHint extends StatelessWidget {
  const _InstallHint({required this.onInstall});
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.extension_rounded, size: 44),
          ),
          const SizedBox(height: 18),
          const Text('还没有安装插件', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '爽听本身不内置任何音源。\n安装 MusicFree 插件后，搜索、播放、歌单、歌词都能用了。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: AppPalette.muted(context)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: onInstall, icon: const Icon(Icons.add_rounded), label: const Tr('安装插件')),
        ],
      ),
    );
  }
}
