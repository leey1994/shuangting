import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/format.dart';
import 'kg_api.dart';
import 'models.dart';
import 'store.dart';

class CachedAudio {
  final File file;
  final String quality;
  const CachedAudio(this.file, this.quality);
}

class AudioCache {
  final KgApi api;
  final SettingsModel settings;
  AudioCache(this.api, this.settings);

  static const qualityOrder = ['hires', 'flac', '320', '128'];

  String _ext(String quality) => quality == 'flac' || quality == 'hires' ? 'flac' : 'mp3';

  Future<File> _fileFor(String hash, String quality) async {
    final dir = await AppPaths.cache();
    return File(p.join(dir.path, '${hash}_$quality.${_ext(quality)}'));
  }

  Future<CachedAudio?> find(Song song) async {
    for (final q in qualityOrder) {
      final f = await _fileFor(song.hash, q);
      if (await f.exists() && await f.length() > 1024) {
        return CachedAudio(f, q);
      }
    }
    return null;
  }

  Future<CachedAudio?> findAnyQuality(Song song) async {
    final dir = await AppPaths.cache();
    if (!await dir.exists()) return null;
    for (final q in qualityOrder) {
      final pattern = RegExp('^${RegExp.escape(song.hash)}_$q\\.(mp3|flac)\$');
      await for (final entity in dir.list()) {
        if (entity is File && pattern.hasMatch(p.basename(entity.path))) {
          return CachedAudio(entity, q);
        }
      }
    }
    return null;
  }

  Future<File> download(
    Song song,
    String quality, {
    String? url,
    void Function(int received, int total)? onProgress,
  }) async {
    final target = await _fileFor(song.hash, quality);
    if (await target.exists() && await target.length() > 1024) return target;

    final resolved = url ??
        (await api.resolveAudio(song, quality))?.url;
    if (resolved == null) throw KgException('无法获取下载地址');

    final client = http.Client();
    final tmp = File('${target.path}.part');
    try {
      final req = http.Request('GET', Uri.parse(resolved));
      req.headers['User-Agent'] = KgApi.userAgent;
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw KgException('下载失败 (${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      if (await tmp.length() < 1024) throw KgException('下载内容异常');
      if (await target.exists()) await target.delete();
      await tmp.rename(target.path);
      unawaited(enforceLimit(settings.cacheLimitMb));
      return target;
    } catch (_) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<int> totalSize() async {
    final dir = await AppPaths.cache();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<int> fileCount() async {
    final dir = await AppPaths.cache();
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final e in dir.list()) {
      if (e is File) count++;
    }
    return count;
  }

  Future<void> clear() async {
    final dir = await AppPaths.cache();
    if (!await dir.exists()) return;
    await for (final e in dir.list()) {
      try {
        await e.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> enforceLimit(int limitMb) async {
    if (limitMb <= 0) return;
    final dir = await AppPaths.cache();
    if (!await dir.exists()) return;
    final files = <File>[];
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) {
        files.add(e);
        try {
          total += await e.length();
        } catch (_) {}
      }
    }
    final limit = limitMb * 1024 * 1024;
    if (total <= limit) return;
    files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
    for (final f in files) {
      if (total <= limit) break;
      try {
        final size = await f.length();
        await f.delete();
        total -= size;
      } catch (_) {}
    }
  }

  Future<void> touch(Song song) async {
    final cached = await findAnyQuality(song);
    if (cached != null) {
      try {
        await cached.file.setLastModified(DateTime.now());
      } catch (_) {}
    }
  }

  String sizeLabel(int bytes) => formatBytes(bytes);
}
