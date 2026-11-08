import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/library_store.dart';
import '../../core/media_cache.dart';
import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../dialogs.dart';
import '../widgets/common.dart';
import 'artist_detail_page.dart';
import 'media_detail_page.dart';
import 'plugin_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const _types = [
    ('music', '单曲'),
    ('album', '专辑'),
    ('artist', '作者'),
    ('sheet', '歌单'),
    ('lyric', '歌词'),
  ];

  String _type = 'music';
  final Set<String> _selected = {};
  final Map<String, List<dynamic>> _results = {};
  final Map<String, int> _pages = {};
  final Map<String, bool> _ended = {};
  final Set<String> _loading = {};
  bool _searched = false;
  List<String> _history = [];
  String _pluginSignature = '';
  final Set<String> _activeSearches = {};

  List<PluginRecord> get _plugins =>
      PluginManager.instance.enabled.where((e) => e.methods.contains('search')).toList();

  String _currentPluginSignature() => _plugins
      .map((e) => '${e.platform}:${e.enabled}:${e.methods.length}:${e.supportedSearchType.join(",")}')
      .join('|');

  @override
  void initState() {
    super.initState();
    _history = PrefStore.instance.getJsonList('searchHistory').map((e) => e.toString()).toList();
    for (final p in _plugins) {
      _selected.add(p.platform);
    }
    _pluginSignature = _currentPluginSignature();
    PluginManager.instance.addListener(_onPlugins);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PluginManager.instance.warmup());
    });
  }

  void _onPlugins() {
    if (!mounted) return;
    final signature = _currentPluginSignature();
    if (signature == _pluginSignature) return;
    _pluginSignature = signature;
    setState(() {
      final valid = _plugins.map((e) => e.platform).toSet();
      _selected.removeWhere((e) => !valid.contains(e));
      if (_selected.isEmpty) _selected.addAll(valid);
    });
  }

  @override
  void dispose() {
    PluginManager.instance.removeListener(_onPlugins);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _saveHistory(String query) async {
    if (query.trim().isEmpty) return;
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > 12) _history = _history.take(12).toList();
    await PrefStore.instance.setJson('searchHistory', _history);
  }

  List<PluginRecord> get _targets =>
      _plugins.where((e) => _selected.contains(e.platform) && e.supportedSearchType.contains(_type)).toList();

  Future<void> _search({bool reset = true, String? onlyPlatform}) async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _focus.requestFocus();
      return;
    }
    final targets = _targets.where((e) => onlyPlatform == null || e.platform == onlyPlatform).toList();
    if (targets.isEmpty) {
      setState(() {
        _searched = true;
        _results.clear();
      });
      return;
    }
    final guard = '$_type|$query|${onlyPlatform ?? ''}|$reset';
    if (_activeSearches.contains(guard)) return;
    _activeSearches.add(guard);
    if (reset) {
      _results.clear();
      _pages.clear();
      _ended.clear();
    }
    setState(() {
      _searched = true;
      for (final t in targets) {
        _loading.add(t.platform);
      }
    });
    try {
      final searches = <Future<void>>[];
      for (var i = 0; i < targets.length; i++) {
        final plugin = targets[i];
        searches.add(Future<void>.delayed(Duration(milliseconds: i * 80), () async {
          final page = (_pages[plugin.platform] ?? 0) + 1;
          try {
            final res = await PluginManager.instance.search(plugin, query, page, _type);
            if (res != null) {
              _results.putIfAbsent(plugin.platform, () => []).addAll(res.data);
              _pages[plugin.platform] = page;
              _ended[plugin.platform] = res.isEnd;
            }
          } catch (_) {}
          _loading.remove(plugin.platform);
          if (mounted) setState(() {});
        }));
      }
      await Future.wait(searches);
      await _saveHistory(query);
      if (mounted) setState(() {});
    } finally {
      _activeSearches.remove(guard);
    }
  }

  Future<void> _applyLyric(PluginRecord plugin, MusicItem item) async {
    final current = PlayerService.instance.current;
    if (current == null) {
      showToast(context, '请先播放一首歌');
      return;
    }
    String raw = (item.raw['rawLrc'] ?? item.raw['lrc'] ?? '').toString();
    if (raw.isEmpty) {
      final src = await PluginManager.instance.getLyric(plugin, item);
      raw = src?.text ?? '';
    }
    if (raw.isEmpty) {
      if (mounted) showToast(context, '该结果没有歌词内容');
      return;
    }
    await MediaCache.instance.setLocalLyric(current.key, raw);
    await MediaCache.instance.setCachedLyric(current.key, raw);
    await PlayerService.instance.reloadLyric();
    if (mounted) showToast(context, '已应用到「${current.title}」');
  }

  Future<void> _importSheet() async {
    final plugins = _plugins.where((e) => e.methods.contains('importMusicSheet')).toList();
    if (plugins.isEmpty) {
      showToast(context, '没有插件支持导入歌单');
      return;
    }
    final plugin = await _pickPlugin(plugins, '选择导入歌单的插件');
    if (plugin == null) return;
    final url = await promptText(context, title: '导入歌单', hint: '粘贴歌单链接 / ID');
    if (url == null || url.trim().isEmpty) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final songs = await PluginManager.instance.importMusicSheet(plugin, url.trim());
      if (mounted) Navigator.pop(context);
      if (songs.isEmpty) {
        if (mounted) showToast(context, '没有导入到歌曲');
        return;
      }
      final name = await promptText(context, title: '保存为歌单', initial: '导入歌单 ${DateTime.now().month}-${DateTime.now().day}');
      if (name != null && name.trim().isNotEmpty) {
        final p = LibraryStore.instance.createPlaylist(name.trim());
        await LibraryStore.instance.addSongsToPlaylist(p, songs);
        if (mounted) showToast(context, '已保存「${p.name}」共 ${songs.length} 首');
      } else {
        PlayerService.instance.playQueue(songs);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showToast(context, '导入失败：$e');
      }
    }
  }

  Future<void> _importMusic() async {
    final plugins = _plugins.where((e) => e.methods.contains('importMusicItem')).toList();
    if (plugins.isEmpty) {
      showToast(context, '没有插件支持导入单曲');
      return;
    }
    final plugin = await _pickPlugin(plugins, '选择导入单曲的插件');
    if (plugin == null) return;
    final url = await promptText(context, title: '导入单曲', hint: '粘贴歌曲链接 / ID');
    if (url == null || url.trim().isEmpty) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final song = await PluginManager.instance.importMusicItem(plugin, url.trim());
      if (mounted) Navigator.pop(context);
      if (song == null) {
        if (mounted) showToast(context, '没有导入到歌曲');
        return;
      }
      if (mounted) showSongActions(context, song);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        showToast(context, '导入失败：$e');
      }
    }
  }

  Future<PluginRecord?> _pickPlugin(List<PluginRecord> plugins, String title) {
    return showModalBottomSheet<PluginRecord>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            for (final p in plugins)
              ListTile(
                title: Text(p.platform),
                subtitle: Text(p.displayVersion, style: const TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugins = _plugins;
    return Scaffold(
      appBar: AppBar(
        title: const Tr('搜索'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'sheet') _importSheet();
              if (v == 'music') _importMusic();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'sheet', child: Tr('导入歌单')),
              PopupMenuItem(value: 'music', child: Tr('导入单曲')),
            ],
            icon: const Icon(Icons.add_link_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: t('搜索歌曲、歌手、专辑'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _searched = false;
                              _results.clear();
                            });
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _types.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = _types[i];
                return TagChip(
                  label: item.$2,
                  selected: _type == item.$1,
                  onTap: () {
                    if (_type == item.$1) return;
                    setState(() => _type = item.$1);
                    if (_controller.text.trim().isNotEmpty) _search();
                  },
                );
              },
            ),
          ),
          if (plugins.length > 1)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                itemCount: plugins.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = plugins[i];
                  return TagChip(
                    label: p.platform,
                    selected: _selected.contains(p.platform),
                    onTap: () {
                      setState(() {
                        if (_selected.contains(p.platform)) {
                          _selected.remove(p.platform);
                        } else {
                          _selected.add(p.platform);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 4),
          Expanded(child: _buildBody(plugins)),
        ],
      ),
    );
  }

  Widget _buildBody(List<PluginRecord> plugins) {
    if (plugins.isEmpty) {
      return EmptyView(
        icon: Icons.extension_off_rounded,
        text: '没有可用的搜索插件',
        action: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PluginPage())),
        actionLabel: '安装插件',
      );
    }
    if (!_searched) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_history.isNotEmpty) ...[
            Row(
              children: [
                Text('搜索历史', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    _history.clear();
                    await PrefStore.instance.setJson('searchHistory', []);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _history
                  .map((e) => TagChip(
                        label: e,
                        selected: false,
                        onTap: () {
                          _controller.text = e;
                          _search();
                        },
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 30),
          Center(
            child: Text(
              t('搜点什么吧'),
              style: TextStyle(color: AppPalette.muted(context), fontSize: 13),
            ),
          ),
        ],
      );
    }

    final targets = _targets;
    if (targets.isEmpty) {
      return EmptyView(
        icon: Icons.search_off_rounded,
        text: '所选插件不支持「${_types.firstWhere((e) => e.$1 == _type).$2}」搜索',
      );
    }

    final sections = <Widget>[];
    for (final plugin in targets) {
      final items = _results[plugin.platform] ?? const [];
      final loading = _loading.contains(plugin.platform);
      sections.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(plugin.platform, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text(
              loading ? t('正在搜索') : '${items.length} ${t('条')}',
              style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
            ),
          ],
        ),
      ));
      if (items.isEmpty && !loading) {
        sections.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(t('没有结果'), style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
        ));
        continue;
      }
      final parsed = items.whereType<Map>().map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e))).toList();
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        final raw = items[itemIndex];
        if (raw is! Map) continue;
        final json = Map<String, dynamic>.from(raw);
        switch (_type) {
          case 'music':
            final song = parsed[itemIndex];
            sections.add(MusicTile(
              song: song,
              onTap: () {
                final i = parsed.indexWhere((e) => e.key == song.key);
                PlayerService.instance.playQueue(parsed, startIndex: i < 0 ? 0 : i);
              },
              onMore: () => showSongActions(context, song, contextSongs: parsed),
            ));
            break;
          case 'album':
            final album = AlbumItem.fromJson(json);
            sections.add(ListTile(
              leading: CoverImage(path: album.artwork, size: 48, radius: 12),
              title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [album.artist, album.date, album.worksNum > 0 ? '${album.worksNum} 首' : ''].where((e) => e.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            ));
            break;
          case 'artist':
            final artist = ArtistItem.fromJson(json);
            sections.add(ListTile(
              leading: ClipOval(child: CoverImage(path: artist.avatar, size: 48, radius: 24)),
              title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [if (artist.fans > 0) '${artist.fans} 粉丝', if (artist.worksNum > 0) '${artist.worksNum} 作品'].join(' · '),
                style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArtistDetailPage(artist: artist))),
            ));
            break;
          case 'sheet':
            final sheet = SheetItem.fromJson(json);
            sections.add(ListTile(
              leading: CoverImage(path: sheet.artwork, size: 48, radius: 12),
              title: Text(sheet.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [sheet.artist, sheet.worksNum > 0 ? '${sheet.worksNum} 首' : ''].where((e) => e.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MusicListDetailPage(
                  title: sheet.title,
                  artwork: sheet.artwork,
                  subtitle: sheet.artist,
                  description: sheet.description,
                  sheet: sheet,
                  kind: MediaListKind.sheet,
                ),
              )),
            ));
            break;
          case 'lyric':
            final lyric = MusicItem.fromJson(json);
            sections.add(ListTile(
              leading: CoverImage(path: lyric.artwork, size: 48, radius: 12),
              title: Text(lyric.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [lyric.artist, lyric.album].where((e) => e.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 11, color: AppPalette.muted(context)),
              ),
              trailing: TextButton(
                onPressed: () => _applyLyric(plugin, lyric),
                child: const Tr('应用'),
              ),
              onTap: () async {
                final current = PlayerService.instance.current;
                if (current == null) {
                  showToast(context, '请先播放一首歌');
                  return;
                }
                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (context) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lyric.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('将这首歌的歌词应用到「${current.title}」', style: TextStyle(fontSize: 12, color: AppPalette.muted(context))),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _applyLyric(plugin, lyric);
                              },
                              child: const Tr('应用歌词'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ));
            break;
        }
      }
      sections.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Center(
          child: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : (_ended[plugin.platform] == true
                  ? Tr('没有更多了', style: TextStyle(fontSize: 11, color: AppPalette.muted(context)))
                  : TextButton(
                      onPressed: () => _search(reset: false, onlyPlatform: plugin.platform),
                      child: const Tr('加载更多'),
                    )),
        ),
      ));
    }

    final hasAny = _results.values.any((e) => e.isNotEmpty);
    if (!hasAny) {
      final stillLoading = _loading.isNotEmpty;
      if (stillLoading) return const LoadingView(text: '正在搜索');
      return EmptyView(icon: Icons.search_off_rounded, text: '没有找到相关结果');
    }
    return ListView(children: sections);
  }
}
