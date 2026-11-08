import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../models.dart';
import '../settings.dart';
import 'plugin_runtime.dart';

class _InspectRequest {
  const _InspectRequest(this.source, this.assets);
  final String source;
  final Map<String, String> assets;
}

Future<Map<String, dynamic>> _inspectInIsolate(_InspectRequest request) =>
    PluginRuntime.inspect(request.source, assets: request.assets);

Future<Map<String, String>> _loadRuntimeAssets() async {
  final paths = <String>{PluginRuntime.preludeAsset, ...PluginRuntime.moduleAssetPaths};
  final result = <String, String>{};
  for (final path in paths) {
    try {
      result[path] = await rootBundle.loadString(path);
    } catch (_) {}
  }
  return result;
}

class SearchPageResult {
  SearchPageResult({required this.platform, required this.data, required this.isEnd});
  final String platform;
  final List<dynamic> data;
  final bool isEnd;
}

class PluginManager extends ChangeNotifier {
  PluginManager._();
  static final PluginManager instance = PluginManager._();

  final List<PluginRecord> records = [];
  List<PluginRecord>? _enabledCache;
  final Map<String, PluginRuntime> _runtimes = {};
  final Map<String, _CacheEntry> _cache = {};
  final Set<String> _loading = {};
  Future<void>? _warmupFuture;

  static const _prefsKey = 'pluginRecords';
  static const _cacheTtl = Duration(minutes: 4);

  void touch() {
    _enabledCache = null;
    notifyListeners();
  }

  /// UI build 会频繁读取该列表；排序结果缓存，插件列表变化时失效。
  List<PluginRecord> get enabled {
    final cached = _enabledCache;
    if (cached != null) return cached;
    final result = records.where((e) => e.enabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return _enabledCache = result;
  }

  void _invalidateEnabled() => _enabledCache = null;

  @override
  void notifyListeners() {
    _invalidateEnabled();
    super.notifyListeners();
  }

  PluginRecord? byPlatform(String platform) {
    for (final r in records) {
      if (r.platform == platform) return r;
    }
    return null;
  }

  Future<void> load() async {
    final raw = PrefStore.instance.getJsonList(_prefsKey);
    records
      ..clear()
      ..addAll(raw.whereType<Map>().map((e) => PluginRecord.fromJson(e.map((k, v) => MapEntry(k.toString(), v)))))
      ..sort((a, b) => a.order.compareTo(b.order));

    // 校正：文件丢失的插件移除；新增的 js 文件登记为待初始化
    final files = <String>{};
    if (await AppPaths.plugins.exists()) {
      await for (final f in AppPaths.plugins.list()) {
        if (f is File && f.path.endsWith('.js')) files.add(f.uri.pathSegments.last);
      }
    }
    records.removeWhere((r) => r.file.isNotEmpty && !files.contains(r.file));
    for (final f in files) {
      if (records.any((r) => r.file == f)) continue;
      records.add(PluginRecord(
        platform: f.replaceAll('.js', ''),
        file: f,
        methods: <String>{},
        supportedSearchType: <String>[],
        primaryKey: <String>[],
        variables: <String, String>{},
        installedAt: DateTime.now().millisecondsSinceEpoch,
        order: records.length,
      ));
    }
    records.sort((a, b) => a.order.compareTo(b.order));
    await _persist();
    _resetWarmup();
    notifyListeners();
    // 等首帧过后再预热，避免启动即解析所有大插件。
    unawaited(_delayedWarmup());
  }

  Future<void> _delayedWarmup() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await warmup();
  }

  Future<void> _persist() async {
    for (var i = 0; i < records.length; i++) {
      records[i].order = i;
    }
    await PrefStore.instance.setJson(_prefsKey, records.map((e) => e.toJson()).toList());
  }

  /// 按顺序预热运行时，每次之间让出事件循环，避免多个大插件同时卡 UI。
  Future<void> warmup({int limit = 2}) {
    final running = _warmupFuture;
    if (running != null) return running;
    final future = _doWarmup(limit);
    _warmupFuture = future;
    return future.whenComplete(() => _warmupFuture = null);
  }

  Future<void> _doWarmup(int limit) async {
    final targets = enabled.take(limit).toList();
    for (final record in targets) {
      await runtimeFor(record);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  // Charts are queried on demand by discover UI, not in the plugin warmup path.

  void _resetWarmup() => _warmupFuture = null;

  Future<PluginRuntime?> runtimeFor(PluginRecord record) async {
    if (!record.enabled) return null;
    final cached = _runtimes[record.platform];
    if (cached != null) return cached;
    if (_loading.contains(record.platform)) {
      // 等待首个加载完成
      for (var i = 0; i < 100; i++) {
        await Future.delayed(const Duration(milliseconds: 80));
        final v = _runtimes[record.platform];
        if (v != null) return v;
        if (!_loading.contains(record.platform)) break;
      }
      return _runtimes[record.platform];
    }
    _loading.add(record.platform);
    try {
      final file = pluginFile(record.file);
      if (!await file.exists()) return null;
      final source = await file.readAsString();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final rt = await PluginRuntime.create(source);
      if (rt.metadata.platform.isNotEmpty && rt.metadata.platform != record.platform) {
        record.platform = rt.metadata.platform;
      }
      _runtimes[record.platform] = rt;

      // 首次加载时补全元信息
      if (record.version.isEmpty || record.version == '0.0.0' || record.methods.isEmpty) {
        record
          ..version = rt.metadata.version
          ..author = rt.metadata.author
          ..description = rt.metadata.description
          ..srcUrl = rt.metadata.srcUrl.isEmpty ? record.srcUrl : rt.metadata.srcUrl
          ..supportedSearchType = List<String>.from(rt.metadata.supportedSearchType)
          ..primaryKey = List<String>.from(rt.metadata.primaryKey)
          ..methods = rt.metadata.methods.toSet()
          ..variables = Map<String, String>.from(record.variables);
        for (final v in rt.metadata.userVariables) {
          record.variables.putIfAbsent(v.key, () => '');
        }
        await _persist();
        notifyListeners();
      }
      return rt;
    } catch (e) {
      debugPrint('[plugin] load ${record.platform} failed: $e');
      record.methods = {};
      return null;
    } finally {
      _loading.remove(record.platform);
    }
  }

  // ---------------- 安装 / 更新 / 卸载 ----------------

  Future<List<PluginRecord>> installFromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) throw PluginException('无效链接');
    final res = await http.get(uri, headers: const {'User-Agent': 'Mozilla/5.0 ShuangTing'}).timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PluginException('下载失败 HTTP ${res.statusCode}');
    }
    final text = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
    return installPayload(text, url: url);
  }

  Future<List<PluginRecord>> installPayload(String text, {String? url}) async {
    final trimmed = text.trim();
    if (trimmed.startsWith('{')) {
      dynamic decoded;
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        throw PluginException('JSON 描述文件解析失败');
      }
      if (decoded is Map && decoded['plugins'] is List) {
        final list = decoded['plugins'] as List;
        final installed = <PluginRecord>[];
        for (final item in list) {
          if (item is! Map) continue;
          final pluginUrl = (item['url'] ?? item['srcUrl'] ?? '').toString();
          if (pluginUrl.isEmpty) continue;
          try {
            installed.addAll(await installFromUrl(pluginUrl));
          } catch (_) {
            // 单个插件失败不阻断订阅
          }
        }
        if (installed.isEmpty) throw PluginException('订阅中没有可安装的插件');
        return installed;
      }
      if (decoded is Map && (decoded['url'] ?? decoded['srcUrl']) != null) {
        final pluginUrl = (decoded['url'] ?? decoded['srcUrl']).toString();
        return installFromUrl(pluginUrl);
      }
      throw PluginException('无法识别的 JSON 描述文件');
    }
    final record = await installSource(trimmed);
    if (url != null) {
      record.srcUrl = record.srcUrl.isEmpty ? url : record.srcUrl;
      await _persist();
    }
    _resetWarmup();
    notifyListeners();
    unawaited(warmup());
    return [record];
  }

  Future<PluginRecord> installSource(String source) async {
    // 让安装进度弹窗先绘制；元信息解析放到后台 isolate，避免大插件卡 UI。
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final assets = await _loadRuntimeAssets();
    Map<String, dynamic> metaJson;
    try {
      metaJson = await Isolate.run(() => _inspectInIsolate(_InspectRequest(source, assets)));
    } catch (_) {
      metaJson = await PluginRuntime.inspect(source, assets: assets);
    }
    final meta = PluginMetadata.fromJson(metaJson);

    final existing = byPlatform(meta.platform);
    if (existing != null && _versionCompare(meta.version, existing.version) < 0) {
      throw PluginException('已安装更高版本 ${existing.version}，请先卸载');
    }

    final safeName = meta.platform.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5.-]'), '_');
    final fileName = '${safeName}_${DateTime.now().millisecondsSinceEpoch}.js';
    final file = pluginFile(fileName);
    await file.writeAsString(source);

    _runtimes.remove(meta.platform)?.dispose();
    if (existing != null) {
      final oldFile = pluginFile(existing.file);
      if (existing.file.isNotEmpty && existing.file != fileName && await oldFile.exists()) {
        try {
          await oldFile.delete();
        } catch (_) {}
      }
      records.remove(existing);
    }

    final record = PluginRecord(
      platform: meta.platform,
      version: meta.version,
      author: meta.author,
      description: meta.description,
      srcUrl: meta.srcUrl,
      file: fileName,
      supportedSearchType: meta.supportedSearchType,
      primaryKey: meta.primaryKey,
      methods: meta.methods,
      variables: {for (final v in meta.userVariables) v.key: existing?.variables[v.key] ?? ''},
      enabled: existing?.enabled ?? true,
      order: existing?.order ?? records.length,
      installedAt: DateTime.now().millisecondsSinceEpoch,
    );
    records.add(record);
    _cache.clear();
    await _persist();
    _resetWarmup();
    notifyListeners();
    unawaited(warmup());
    return record;
  }

  Future<bool> updatePlugin(PluginRecord record) async {
    if (record.srcUrl.isEmpty) throw PluginException('该插件未提供更新地址');
    final res = await http.get(Uri.parse(record.srcUrl), headers: const {'User-Agent': 'Mozilla/5.0 ShuangTing'});
    if (res.statusCode < 200 || res.statusCode >= 300) throw PluginException('更新下载失败 HTTP ${res.statusCode}');
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    final updated = await installSource(text);
    return updated.platform == record.platform;
  }

  Future<void> uninstall(PluginRecord record) async {
    _runtimes.remove(record.platform)?.dispose();
    await _deletePluginFile(record);
    records.remove(record);
    _cache.clear();
    await _persist();
    _resetWarmup();
    notifyListeners();
    unawaited(warmup());
  }

  Future<void> _deletePluginFile(PluginRecord record) async {
    final f = pluginFile(record.file);
    if (!await f.exists()) return;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await f.delete();
        return;
      } catch (_) {
        try {
          final orphan = File('${f.path}.orphan');
          await f.rename(orphan.path);
          try {
            await orphan.delete();
          } catch (_) {}
          return;
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> setEnabled(PluginRecord record, bool enabled) async {
    record.enabled = enabled;
    if (!enabled) _runtimes.remove(record.platform)?.dispose();
    await _persist();
    _resetWarmup();
    notifyListeners();
    unawaited(warmup());
  }

  Future<void> setVariables(PluginRecord record, Map<String, String> vars) async {
    record.variables = Map<String, String>.from(vars);
    _runtimes.remove(record.platform)?.dispose();
    await _persist();
    _resetWarmup();
    notifyListeners();
    unawaited(warmup());
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = records.removeAt(oldIndex);
    records.insert(newIndex, item);
    await _persist();
    notifyListeners();
  }

  void clearCaches() {
    _cache.clear();
  }

  // ---------------- 调用封装 ----------------

  Future<PluginCallResult> _call(PluginRecord record, String method, List<dynamic> args,
      {Duration timeout = const Duration(seconds: 25)}) async {
    final rt = await runtimeFor(record);
    if (rt == null) return PluginCallResult(error: '插件不可用');
    return rt.call(method, args, timeout: timeout);
  }

  String _cacheKey(String platform, String method, List<dynamic> args) =>
      '$platform::$method::${jsonEncode(args, toEncodable: (o) => o is MusicItem ? o.toJson() : '$o')}';

  T? _getCached<T>(String key) {
    if (key.contains('getTop') || key.contains('recommend')) _cache.remove(key);
    final e = _cache[key];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return e.value as T?;
  }

  void _setCached(String key, dynamic value) {
    if (_cache.length > 300) _cache.clear();
    _cache[key] = _CacheEntry(value, DateTime.now());
  }

  // ---------------- 业务接口 ----------------

  Future<SearchPageResult?> search(
    PluginRecord record,
    String query,
    int page,
    String type,
  ) async {
    if (!record.methods.contains('search')) return null;
    final key = _cacheKey(record.platform, 'search', [query, page, type]);
    final cached = _getCached<SearchPageResult>(key);
    if (cached != null) return cached;
    final res = await _call(record, 'search', [query, page, type], timeout: const Duration(seconds: 30));
    if (!res.ok || res.value is! Map) return null;
    final map = Map<String, dynamic>.from(res.value as Map);
    final result = SearchPageResult(
      platform: record.platform,
      data: (map['data'] as List?) ?? const [],
      isEnd: map['isEnd'] == true,
    );
    _setCached(key, result);
    return result;
  }

  Future<MediaSourceInfo?> getMediaSource(PluginRecord record, MusicItem item,
      {String quality = 'standard'}) async {
    final order = _qualityOrder(quality);
    for (final q in order) {
      final key = _cacheKey(record.platform, 'source:$q', [item]);
      final cached = _getCached<MediaSourceInfo>(key);
      if (cached != null && (cached.url ?? '').isNotEmpty) return cached;
      final res = await _call(record, 'getMediaSource', [item.toJson(), q],
          timeout: const Duration(seconds: 18));
      if (!res.ok || res.value is! Map) continue;
      var info = MediaSourceInfo.fromJson(Map<String, dynamic>.from(res.value as Map));
      if ((info.url ?? '').isNotEmpty) {
        if (info.statusCode != null && (info.statusCode! < 200 || info.statusCode! >= 400)) continue;
        if (info.mimeType != null && _looksLikeErrorMime(info.mimeType!)) continue;
        if (!await _probeAudio(info)) continue;
        _setCached(key, info);
        return info;
      }
    }
    return null;
  }

  bool _looksLikeErrorMime(String mime) {
    final value = mime.toLowerCase();
    return value.contains('text/html') || value.contains('application/json');
  }

  Future<bool> _probeAudio(MediaSourceInfo info) async {
    HttpClient? client;
    try {
      final uri = Uri.parse(info.url!);
      if (!const {'http', 'https'}.contains(uri.scheme)) return false;
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final req = await client.openUrl('GET', uri);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
      info.headers.forEach((k, v) {
        if (!const {'host', 'content-length', 'range', 'connection'}.contains(k.toLowerCase())) {
          req.headers.set(k, v);
        }
      });
      if (info.userAgent?.isNotEmpty == true) {
        req.headers.set(HttpHeaders.userAgentHeader, info.userAgent!);
      }
      final resp = await req.close().timeout(const Duration(seconds: 6));
      final type = (resp.headers.contentType?.mimeType ?? '').toLowerCase();
      await resp.drain<void>();
      final okStatus = resp.statusCode >= 200 && resp.statusCode < 300;
      final okType = !_looksLikeErrorMime(type);
      return okStatus && okType;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  List<String> _qualityOrder(String preferred) {
    const all = ['super', 'high', 'standard', 'low'];
    final order = <String>[preferred];
    for (final q in all) {
      if (!order.contains(q)) order.add(q);
    }
    return order;
  }

  Future<LyricSource?> getLyric(PluginRecord record, MusicItem item) async {
    if (!record.methods.contains('getLyric')) return null;
    final key = _cacheKey(record.platform, 'lyric', [item]);
    final cached = _getCached<LyricSource>(key);
    if (cached != null) return cached;
    final res = await _call(record, 'getLyric', [item.toJson()]);
    if (!res.ok || res.value == null) return null;
    final lyric = LyricSource.fromJson(res.value);
    if (lyric.text.isEmpty) return null;
    _setCached(key, lyric);
    return lyric;
  }

  /// 跨插件自动匹配歌词：先用原曲取，再按标题在其它源搜索候选取词。
  Future<String?> autoMatchLyric(MusicItem song) async {
    final wanted = _normalizeTitle(song.title);
    if (wanted.length < 2) return null;
    final query = song.artist.trim().isEmpty ? song.title.trim() : '${song.title.trim()} ${song.artist.trim()}';
    final plugins = enabled
        .where((e) => e.methods.contains('getLyric') || e.supportedSearchType.contains('lyric'))
        .take(5)
        .toList();

    for (final plugin in plugins) {
      if (plugin.methods.contains('getLyric')) {
        try {
          final direct = await getLyric(plugin, song).timeout(const Duration(seconds: 6));
          if (direct != null && direct.text.isNotEmpty) return direct.text;
        } catch (_) {}
      }

      for (final type in const ['music', 'lyric']) {
        if (!plugin.methods.contains('search')) continue;
        if (type == 'lyric' && !plugin.supportedSearchType.contains('lyric')) continue;
        try {
          final res = await search(plugin, query, 1, type).timeout(const Duration(seconds: 8));
          for (final raw in (res?.data ?? const []).whereType<Map>().take(4)) {
            final map = Map<String, dynamic>.from(raw)
              ..putIfAbsent('platform', () => plugin.platform);
            final candidate = MusicItem.fromJson(map);
            if (!_titleMatches(wanted, candidate.title)) continue;
            final inline = (map['rawLrc'] ?? map['lrc'] ?? '').toString();
            if (inline.isNotEmpty) return inline;
            if (plugin.methods.contains('getLyric')) {
              final src = await getLyric(plugin, candidate).timeout(const Duration(seconds: 6));
              if (src != null && src.text.isNotEmpty) return src.text;
            }
          }
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return null;
  }

  String _normalizeTitle(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-—_·（）()\[\]《》【】,，.。!！?？]'), '');

  bool _titleMatches(String wanted, String candidate) {
    final other = _normalizeTitle(candidate);
    if (other.length < 2) return false;
    return other == wanted || other.contains(wanted) || wanted.contains(other);
  }

  Future<Map<String, dynamic>?> getAlbumInfo(PluginRecord record, AlbumItem album, int page) async {
    final res = await _call(record, 'getAlbumInfo', [album.toJson(), page]);
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  Future<Map<String, dynamic>?> getMusicSheetInfo(PluginRecord record, SheetItem sheet, int page) async {
    final res = await _call(record, 'getMusicSheetInfo', [sheet.toJson(), page]);
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  Future<Map<String, dynamic>?> getTopListDetail(PluginRecord record, SheetItem item, int page) async {
    final res = await _call(record, 'getTopListDetail', [item.toJson(), page],
        timeout: const Duration(seconds: 10));
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  Future<List<dynamic>> getTopLists(PluginRecord record) async {
    final res = await _call(record, 'getTopLists', [], timeout: const Duration(seconds: 8));
    if (!res.ok || res.value is! List) return const [];
    return res.value as List;
  }

  Future<Map<String, dynamic>?> getArtistWorks(
      PluginRecord record, ArtistItem artist, int page, String type) async {
    final res = await _call(record, 'getArtistWorks', [artist.toJson(), page, type]);
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  Future<Map<String, dynamic>?> getRecommendSheetTags(PluginRecord record) async {
    final res = await _call(record, 'getRecommendSheetTags', [],
        timeout: const Duration(seconds: 8));
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  Future<Map<String, dynamic>?> getRecommendSheetsByTag(
      PluginRecord record, Map<String, dynamic> tag, int page) async {
    final res = await _call(record, 'getRecommendSheetsByTag', [tag, page],
        timeout: const Duration(seconds: 10));
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  Future<MusicItem?> getMusicInfo(PluginRecord record, MusicItem item) async {
    final res = await _call(record, 'getMusicInfo', [item.toJson()]);
    if (!res.ok || res.value is! Map) return null;
    return MusicItem.fromJson(Map<String, dynamic>.from(res.value as Map));
  }

  Future<List<MusicItem>> importMusicSheet(PluginRecord record, String url) async {
    final res = await _call(record, 'importMusicSheet', [url], timeout: const Duration(seconds: 35));
    if (!res.ok || res.value is! List) return const [];
    return (res.value as List)
        .whereType<Map>()
        .map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MusicItem?> importMusicItem(PluginRecord record, String url) async {
    final res = await _call(record, 'importMusicItem', [url], timeout: const Duration(seconds: 35));
    if (!res.ok || res.value is! Map) return null;
    return MusicItem.fromJson(Map<String, dynamic>.from(res.value as Map));
  }

  Future<Map<String, dynamic>?> getMusicComments(PluginRecord record, MusicItem item, int page) async {
    final res = await _call(record, 'getMusicComments', [item.toJson(), page]);
    if (!res.ok || res.value is! Map) return null;
    return Map<String, dynamic>.from(res.value as Map);
  }

  static int _versionCompare(String a, String b) {
    final pa = a.split(RegExp(r'[.+-]')).map((e) => int.tryParse(e) ?? 0).toList();
    final pb = b.split(RegExp(r'[.+-]')).map((e) => int.tryParse(e) ?? 0).toList();
    final len = max(pa.length, pb.length);
    for (var i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  @override
  void dispose() {
    for (final r in _runtimes.values) {
      r.dispose();
    }
    _runtimes.clear();
    super.dispose();
  }
}

class _CacheEntry {
  _CacheEntry(this.value, this.at);
  final dynamic value;
  final DateTime at;
}
