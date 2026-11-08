import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:quickjs_engine/quickjs_engine.dart';

import '../models.dart';
import '../settings.dart';

class PluginCallResult {
  PluginCallResult({this.value, this.error, this.unsupported = false});
  final dynamic value;
  final String? error;
  final bool unsupported;

  bool get ok => error == null && !unsupported;
}

class PluginMetadata {
  PluginMetadata({
    required this.platform,
    required this.version,
    required this.author,
    required this.description,
    required this.srcUrl,
    required this.supportedSearchType,
    required this.primaryKey,
    required this.methods,
    required this.userVariables,
    required this.defaultSearchType,
  });

  final String platform;
  final String version;
  final String author;
  final String description;
  final String srcUrl;
  final List<String> supportedSearchType;
  final List<String> primaryKey;
  final Set<String> methods;
  final List<UserVariable> userVariables;
  final String defaultSearchType;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'version': version,
        'author': author,
        'description': description,
        'srcUrl': srcUrl,
        'supportedSearchType': supportedSearchType,
        'primaryKey': primaryKey,
        'methods': methods.toList(),
        'userVariables': userVariables.map((e) => e.toJson()).toList(),
        'defaultSearchType': defaultSearchType,
      };

  factory PluginMetadata.fromJson(Map<String, dynamic> json) => PluginMetadata(
        platform: (json['platform'] ?? '').toString(),
        version: (json['version'] ?? '0.0.0').toString(),
        author: (json['author'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        srcUrl: (json['srcUrl'] ?? '').toString(),
        supportedSearchType: ((json['supportedSearchType'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        primaryKey: ((json['primaryKey'] as List?) ?? const ['id'])
            .map((e) => e.toString())
            .toList(),
        methods: ((json['methods'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
        userVariables: ((json['userVariables'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => UserVariable.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        defaultSearchType: (json['defaultSearchType'] ?? 'music').toString(),
      );
}

/// 单个 MusicFree 插件的 QuickJS 运行时。
class PluginRuntime {
  PluginRuntime._(this.runtime, this.metadata, this.source);

  final JavascriptRuntime runtime;
  final PluginMetadata metadata;
  final String source;

  bool _disposed = false;
  Future<void> _tail = Future.value();

  static const preludeAsset = 'assets/js/prelude.js';

  static const _moduleAssets = <String, String>{
    'axios': 'assets/js/modules/axios.js',
    'cheerio': 'assets/js/modules/cheerio.js',
    'crypto-js': 'assets/js/modules/crypto-js.min.js',
    'dayjs': 'assets/js/modules/dayjs.min.js',
    'qs': 'assets/js/modules/qs.min.js',
    'he': 'assets/js/modules/he.min.js',
    'big-integer': 'assets/js/modules/BigInteger.min.js',
    '@react-native-cookies/cookies': 'assets/js/modules/cookies.js',
    'react-native': 'assets/js/modules/cookies.js',
  };

  static Iterable<String> get moduleAssetPaths => _moduleAssets.values;

  static const _alias = <String, String>{
    'crypto': 'crypto-js',
    'cryptojs': 'crypto-js',
    'CryptoJS': 'crypto-js',
    'bigint': 'big-integer',
    'jsbn': 'big-integer',
  };

  static Future<PluginRuntime> create(
    String source, {
    Duration timeout = const Duration(seconds: 12),
    Map<String, String>? assets,
  }) async {
    final runtime = getJavascriptRuntime(xhr: false);
    runtime.enableHandlePromises();

    Future<String> readAsset(String path) async => assets?[path] ?? rootBundle.loadString(path);

    final prelude = await readAsset('assets/js/prelude.js');
    final evalPrelude = runtime.evaluate(prelude);
    if (evalPrelude.isError) {
      runtime.dispose();
      throw PluginException('运行时初始化失败: ${evalPrelude.stringResult}');
    }
    _installFetch(runtime);

    final loadedModules = <String, String>{};

    Future<String> loadModule(String name) async {
      final key = _alias[name] ?? name;
      final cached = loadedModules[key];
      if (cached != null) return cached;
      final path = _moduleAssets[key];
      if (path == null) return '';
      try {
        final text = await readAsset(path);
        loadedModules[key] = text;
        return text;
      } catch (_) {
        return '';
      }
    }

    // 预加载全部内置模块（插件常见动态 require 无法静态扫描，直接全量装进缓存）
    for (final name in _moduleAssets.keys) {
      await loadModule(name);
    }

    runtime.onMessage('ModuleSource', (dynamic args) {
      var name = args?.toString() ?? '';
      if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
        try {
          name = jsonDecode(name) as String;
        } catch (_) {
          name = name.substring(1, name.length - 1);
        }
      }
      final key = _alias[name] ?? name;
      return loadedModules[key] ?? '';
    });

    await Future<void>.delayed(Duration.zero);

    final wrapped = '''
(function () {
  var module = { exports: {} };
  var exports = module.exports;
  var require = globalThis.__require;
  try {
$source
  } catch (e) {
    globalThis.__pluginLoadError = String((e && (e.message || e)) || e) + ' @ ' + String((e && e.stack) || '');
  }
  globalThis.__plugin = module.exports;
})();
''';

    final evalPlugin = runtime.evaluate(wrapped);
    if (evalPlugin.isError) {
      runtime.dispose();
      throw PluginException('插件语法错误: ${evalPlugin.stringResult}');
    }

    final error = runtime.evaluate('globalThis.__pluginLoadError || ""');
    if (!error.isError && error.stringResult.isNotEmpty && error.stringResult != 'null') {
      runtime.dispose();
      throw PluginException('插件加载失败: ${error.stringResult}');
    }

    final metaResult = runtime.evaluate('''
JSON.stringify((function () {
  var p = globalThis.__plugin || {};
  var fns = {};
  Object.keys(p).forEach(function (k) { if (typeof p[k] === 'function') fns[k] = 1; });
  var vars = [];
  try { vars = (p.userVariables || []).map(function (v) {
    return { key: String(v.key || ''), name: v.name, hint: v.hint };
  }); } catch (e) {}
  return {
    platform: String(p.platform || ''),
    version: String(p.version || ''),
    author: String(p.author || ''),
    description: String(p.description || ''),
    srcUrl: String(p.srcUrl || ''),
    supportedSearchType: Array.isArray(p.supportedSearchType) ? p.supportedSearchType.map(String) : [],
    primaryKey: Array.isArray(p.primaryKey) ? p.primaryKey.map(String) : ['id'],
    defaultSearchType: String(p.defaultSearchType || ''),
    methods: Object.keys(fns),
    userVariables: vars
  };
})())
''');

    Map<String, dynamic> meta = {};
    if (!metaResult.isError) {
      try {
        meta = jsonDecode(metaResult.stringResult) as Map<String, dynamic>;
      } catch (_) {}
    }

    final platform = (meta['platform'] ?? '').toString();
    if (platform.isEmpty) {
      runtime.dispose();
      throw PluginException('插件未导出 platform 字段');
    }

    final methods = ((meta['methods'] as List?) ?? []).map((e) => e.toString()).toSet();
    final searchTypes = ((meta['supportedSearchType'] as List?) ?? []).map((e) => e.toString()).toList();
    final defaultType = (meta['defaultSearchType'] ?? '').toString();

    final metadata = PluginMetadata(
      platform: platform,
      version: (meta['version'] ?? '0.0.0').toString(),
      author: (meta['author'] ?? '').toString(),
      description: (meta['description'] ?? '').toString(),
      srcUrl: (meta['srcUrl'] ?? '').toString(),
      supportedSearchType: searchTypes.isEmpty
          ? (methods.contains('search') ? const ['music'] : const [])
          : searchTypes,
      primaryKey: ((meta['primaryKey'] as List?) ?? ['id']).map((e) => e.toString()).toList(),
      methods: methods,
      userVariables: ((meta['userVariables'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => UserVariable.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList(),
      defaultSearchType: defaultType.isEmpty ? (searchTypes.isNotEmpty ? searchTypes.first : 'music') : defaultType,
    );

    return PluginRuntime._(runtime, metadata, source);
  }

  /// 只解析插件元信息后立即释放运行时，可在后台 isolate 中执行。
  static Future<Map<String, dynamic>> inspect(String source, {Map<String, String>? assets}) async {
    final rt = await create(source, assets: assets);
    final result = rt.metadata.toJson();
    rt.dispose();
    return result;
  }

  bool supports(String method) => metadata.methods.contains(method);

  /// prelude 里的 fetch 通过 sendMessage('Fetch') 把请求交给 Dart，
  /// 用 package:http 真实发请求，完成后回填 Promise（避开 quickjs_engine 自带
  /// XHR 桥在部分环境下回调丢失的问题）。
  static void _installFetch(JavascriptRuntime runtime) {
    runtime.onMessage('Fetch', (dynamic args) {
      Map<String, dynamic>? req;
      if (args is Map) {
        req = Map<String, dynamic>.from(args);
      } else {
        try {
          req = Map<String, dynamic>.from(jsonDecode(args.toString()) as Map);
        } catch (_) {}
      }
      if (req == null) return '';
      unawaited(_runFetch(runtime, req));
      return '';
    });
  }

  static Future<void> _runFetch(JavascriptRuntime runtime, Map<String, dynamic> req) async {
    final id = req['id'];
    final headers = <String, String>{};
    (req['headers'] as Map?)?.forEach((k, v) {
      final key = k.toString();
      if (const ['host', 'content-length', 'connection'].contains(key.toLowerCase())) return;
      headers[key] = v.toString();
    });
    var status = 0;
    var statusText = '';
    var body = '';
    var bodyBase64 = '';
    final responseHeaders = <String, String>{};
    try {
      final uri = Uri.parse(req['url'].toString());
      final method = (req['method'] ?? 'GET').toString().toUpperCase();
      final payload = req['body']?.toString();
      late http.Response r;
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: headers, body: payload);
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: payload);
          break;
        case 'PATCH':
          r = await http.patch(uri, headers: headers, body: payload);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers, body: payload);
          break;
        case 'HEAD':
          r = await http.head(uri, headers: headers);
          break;
        default:
          r = await http.get(uri, headers: headers);
      }
      status = r.statusCode;
      statusText = r.reasonPhrase ?? '';
      body = utf8.decode(r.bodyBytes, allowMalformed: true);
      bodyBase64 = base64Encode(r.bodyBytes);
      r.headers.forEach((k, v) => responseHeaders[k] = v);
    } catch (e) {
      body = '$e';
    }
    final encoded = jsonEncode({
      'status': status,
      'statusText': statusText,
      'headers': responseHeaders,
      'body': body,
      'bodyBase64': bodyBase64,
    });
    try {
      runtime.evaluate('globalThis.__fetchFinish(${jsonEncode(id)}, ${jsonEncode(encoded)})');
    } catch (_) {}
  }

  /// 串行调用：同一运行时同一时刻只跑一个插件函数。
  Future<PluginCallResult> call(String method, List<dynamic> args,
      {Duration timeout = const Duration(seconds: 25)}) async {
    if (_disposed) return PluginCallResult(error: '插件已卸载');
    if (!supports(method)) return PluginCallResult(unsupported: true);

    final completer = Completer<PluginCallResult>();
    _tail = _tail.then((_) async {
      try {
        final argJson = _encodeArgs(args);
        final eval = runtime.evaluate('globalThis.__invoke(${jsonEncode(method)}, $argJson)');
        if (eval.isError) {
          completer.complete(PluginCallResult(error: eval.stringResult));
          return;
        }
        final resolved = await runtime.handlePromise(eval, timeout: timeout);
        final text = resolved.stringResult;
        Map<String, dynamic>? payload;
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) payload = decoded.map((k, v) => MapEntry(k.toString(), v));
        } catch (_) {}
        if (payload == null) {
          completer.complete(PluginCallResult(error: '插件返回了无法解析的数据: ${_truncate(text)}'));
          return;
        }
        if (payload['ok'] == true) {
          completer.complete(PluginCallResult(value: payload['value']));
        } else {
          completer.complete(PluginCallResult(
            error: (payload['err'] ?? '插件调用失败').toString(),
            unsupported: payload['unsupported'] == true,
          ));
        }
      } catch (e) {
        completer.complete(PluginCallResult(error: _truncate('$e')));
      }
    }).catchError((_) {});
    return completer.future;
  }

  static String _encodeArgs(List<dynamic> args) {
    try {
      return jsonEncode(args, toEncodable: (o) {
        if (o is MusicItem) return o.toJson();
        if (o is AlbumItem) return o.toJson();
        if (o is ArtistItem) return o.toJson();
        if (o is SheetItem) return o.toJson();
        return o.toString();
      });
    } catch (_) {
      return '[]';
    }
  }

  static String _truncate(String s) => s.length > 400 ? '${s.substring(0, 400)}…' : s;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      runtime.dispose();
    } catch (_) {}
  }
}

class PluginException implements Exception {
  PluginException(this.message);
  final String message;
  @override
  String toString() => message;
}

File pluginFile(String fileName) => File('${AppPaths.plugins.path}/$fileName');
