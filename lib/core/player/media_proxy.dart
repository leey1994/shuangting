import 'dart:async';
import 'dart:io';
import 'dart:math';

/// 本地音频代理：为需要 Referer / Cookie / UA 的音源补请求头。
///
/// audioplayers 不支持自定义请求头，因此所有远程音频都经由 127.0.0.1 的
/// 短连接代理播放；条目只存在内存中，进程退出即失效。
class MediaProxy {
  MediaProxy._();
  static final MediaProxy instance = MediaProxy._();

  HttpServer? _server;
  final Map<String, _ProxyEntry> _entries = {};
  final _random = Random.secure();

  Future<void> ensureStarted() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (_) {});
  }

  String register(String url, Map<String, String> headers, {String? userAgent}) {
    final id = List.generate(20, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final merged = Map<String, String>.from(headers);
    if (userAgent != null && userAgent.isNotEmpty) {
      merged.putIfAbsent('User-Agent', () => userAgent);
    }
    _entries[id] = _ProxyEntry(url, merged);
    if (_entries.length > 200) {
      final first = _entries.keys.take(_entries.length - 150).toList();
      for (final k in first) {
        _entries.remove(k);
      }
    }
    final port = _server?.port ?? 0;
    return 'http://127.0.0.1:$port/p/$id';
  }

  Future<void> _handle(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.length < 2 || segments.first != 'p') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    final entry = _entries[segments[1]];
    if (entry == null) {
      request.response.statusCode = HttpStatus.gone;
      await request.response.close();
      return;
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final target = Uri.parse(entry.url);
      final upstream = await client.openUrl(request.method, target);
      entry.headers.forEach((k, v) {
        if (const {'host', 'content-length', 'connection'}.contains(k.toLowerCase())) return;
        upstream.headers.set(k, v);
      });
      for (final name in [HttpHeaders.rangeHeader, HttpHeaders.ifRangeHeader]) {
        final value = request.headers.value(name);
        if (value != null) upstream.headers.set(name, value);
      }
      final remote = await upstream.close();
      final response = request.response..statusCode = remote.statusCode;
      for (final name in [
        HttpHeaders.contentTypeHeader,
        HttpHeaders.contentLengthHeader,
        HttpHeaders.contentRangeHeader,
        HttpHeaders.acceptRangesHeader,
        HttpHeaders.lastModifiedHeader,
        'etag',
        'content-disposition',
      ]) {
        final value = remote.headers.value(name);
        if (value != null) response.headers.set(name, value);
      }
      response.headers.set(HttpHeaders.connectionHeader, 'close');
      if (request.method != 'HEAD') await response.addStream(remote);
      await response.close();
    } catch (e) {
      try {
        request.response
          ..statusCode = HttpStatus.badGateway
          ..write('Audio proxy error: $e');
        await request.response.close();
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
  }
}

class _ProxyEntry {
  _ProxyEntry(this.url, this.headers);
  final String url;
  final Map<String, String> headers;
}
