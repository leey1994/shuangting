import 'package:flutter/material.dart' hide Text;
import '../widgets/l10n_text.dart';

import '../../core/media_cache.dart';
import '../../core/models.dart';
import '../../core/player/player_service.dart';
import '../../core/plugin/plugin_manager.dart';
import '../../core/theme.dart';
import '../widgets/common.dart';

class LyricSearchPage extends StatefulWidget {
  const LyricSearchPage({super.key, required this.song});
  final MusicItem song;

  @override
  State<LyricSearchPage> createState() => _LyricSearchPageState();
}

class _LyricSearchPageState extends State<LyricSearchPage> {
  late final TextEditingController _query;
  PluginRecord? _plugin;
  final Map<String, List<MusicItem>> _results = {};
  final Map<String, int> _pages = {};
  final Set<String> _ended = {};
  bool _searching = false;
  String? _error;

  List<PluginRecord> get _plugins =>
      PluginManager.instance.enabled.where((e) => e.methods.contains('search')).toList();

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: '${widget.song.title} ${widget.song.artist}'.trim());
    final list = _plugins;
    _plugin = list.isEmpty ? null : list.first;
    WidgetsBinding.instance.addPostFrameCallback((_) => _search(reset: true));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search({bool reset = false}) async {
    final plugin = _plugin;
    if (plugin == null) return;
    if (reset) {
      _results.clear();
      _pages.clear();
      _ended.clear();
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    final page = (_pages[plugin.platform] ?? 0) + 1;
    try {
      final res = await PluginManager.instance.search(plugin, _query.text.trim(), page, 'lyric');
      if (!mounted) return;
      if (res == null) {
        setState(() => _error = '该插件不支持歌词搜索');
      } else {
        final items = res.data
            .whereType<Map>()
            .map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _results.putIfAbsent(plugin.platform, () => []).addAll(items);
          _pages[plugin.platform] = page;
          if (res.isEnd) _ended.add(plugin.platform);
          if (items.isEmpty && page == 1) _error = '没有找到歌词';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _apply(MusicItem item) async {
    final plugin = _plugin;
    if (plugin == null) return;
    String raw = (item.raw['rawLrc'] ?? item.raw['lrc'] ?? '').toString();
    if (raw.isEmpty) {
      final src = await PluginManager.instance.getLyric(plugin, item);
      raw = src?.text ?? '';
    }
    if (raw.isEmpty) {
      if (mounted) showToast(context, '该结果没有歌词内容');
      return;
    }
    await MediaCache.instance.setLocalLyric(widget.song.key, raw);
    await MediaCache.instance.setCachedLyric(widget.song.key, raw);
    await PlayerService.instance.reloadLyric();
    if (mounted) {
      showToast(context, '歌词已应用');
      Navigator.pop(context);
    }
  }

  Future<void> _showPreview(MusicItem item) async {
    final plugin = _plugin;
    if (plugin == null) return;
    String raw = (item.raw['rawLrc'] ?? item.raw['lrc'] ?? '').toString();
    if (raw.isEmpty) {
      setState(() => _searching = true);
      final src = await PluginManager.instance.getLyric(plugin, item);
      raw = src?.text ?? '';
      if (mounted) setState(() => _searching = false);
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            TextButton(onPressed: () async {
              Navigator.pop(context);
              await _apply(item);
            }, child: const Text('应用')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              raw.isEmpty ? '该结果没有歌词内容' : raw,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭'))],
      ),
    );
  }

  Future<void> _pasteLyric() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('粘贴歌词'),
        content: TextField(
          controller: controller,
          maxLines: 12,
          decoration: const InputDecoration(hintText: '支持 LRC 时间戳，也支持纯文本'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Tr('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Tr('保存')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty) return;
    await MediaCache.instance.setLocalLyric(widget.song.key, text);
    await MediaCache.instance.setCachedLyric(widget.song.key, text);
    await PlayerService.instance.reloadLyric();
    if (mounted) {
      showToast(context, '歌词已保存');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _results[_plugin?.platform] ?? const <MusicItem>[];
    return Scaffold(
      appBar: AppBar(
        title: const Tr('搜索歌词'),
        actions: [
          TextButton.icon(onPressed: _pasteLyric, icon: const Icon(Icons.content_paste_rounded, size: 18), label: const Text('粘贴')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(reset: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                      hintText: '歌曲名 / 歌手',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(onPressed: _searching ? null : () => _search(reset: true), child: const Tr('搜索')),
              ],
            ),
          ),
          if (_plugins.length > 1)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _plugins.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = _plugins[i];
                  return TagChip(
                    label: p.platform,
                    selected: p.platform == _plugin?.platform,
                    onTap: () {
                      setState(() => _plugin = p);
                      if (!_results.containsKey(p.platform)) _search(reset: true);
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: _searching && items.isEmpty
                ? const LoadingView(text: '正在搜索歌词')
                : items.isEmpty
                    ? EmptyView(
                        icon: Icons.lyrics_outlined,
                        text: _error ?? '输入关键词搜索歌词',
                        action: _plugins.isEmpty ? null : () => _search(reset: true),
                        actionLabel: '搜索',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: items.length + 1,
                        itemBuilder: (context, i) {
                          if (i == items.length) {
                            final ended = _ended.contains(_plugin?.platform);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              child: Center(
                                child: ended
                                    ? Tr('没有更多了', style: TextStyle(fontSize: 12, color: AppPalette.muted(context)))
                                    : OutlinedButton(
                                        onPressed: _searching ? null : () => _search(),
                                        child: _searching
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Tr('加载更多'),
                                      ),
                              ),
                            );
                          }
                          final item = items[i];
                          return ListTile(
                            leading: CoverImage(path: item.artwork, size: 42, radius: 10),
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [item.artist, item.album].where((e) => e.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: AppPalette.muted(context)),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _showPreview(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
