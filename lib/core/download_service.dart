import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'media_cache.dart';
import 'models.dart';
import 'plugin/plugin_manager.dart';
import 'settings.dart';

enum DownloadStatus { waiting, downloading, completed, failed, canceled }

class DownloadTask {
  DownloadTask({required this.song, this.status = DownloadStatus.waiting, this.progress = 0, this.path = '', this.error});
  final MusicItem song;
  DownloadStatus status;
  double progress;
  String path;
  String? error;
  bool canceled = false;
}

class DownloadService extends ChangeNotifier {
  DownloadService._();
  static final DownloadService instance = DownloadService._();

  final List<DownloadTask> tasks = [];
  int _running = 0;
  final List<DownloadTask> _queue = [];

  static const _prefsKey = 'downloadTasks';

  Future<void> load() async {
    final raw = PrefStore.instance.getJsonList(_prefsKey);
    tasks.clear();
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final songMap = map['song'];
      if (songMap is! Map) continue;
      final path = (map['path'] ?? '').toString();
      final exists = path.isNotEmpty && await File(path).exists();
      if (!exists) continue;
      tasks.add(DownloadTask(
        song: MusicItem.fromJson(Map<String, dynamic>.from(songMap)),
        status: DownloadStatus.completed,
        progress: 1,
        path: path,
      ));
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final completed = tasks.where((e) => e.status == DownloadStatus.completed);
    await PrefStore.instance.setJson(_prefsKey, completed.map((e) => {
          'song': e.song.toJson(),
          'path': e.path,
        }).toList());
  }

  DownloadTask? taskFor(String key) {
    for (final t in tasks) {
      if (t.song.key == key) return t;
    }
    return null;
  }

  Future<void> enqueue(MusicItem song) async {
    if (taskFor(song.key) != null) return;
    final task = DownloadTask(song: song);
    tasks.add(task);
    _queue.add(task);
    notifyListeners();
    _pump();
  }

  Future<void> enqueueAll(List<MusicItem> songs) async {
    for (final s in songs) {
      if (taskFor(s.key) == null) {
        final task = DownloadTask(song: s);
        tasks.add(task);
        _queue.add(task);
      }
    }
    notifyListeners();
    _pump();
  }

  Future<void> _pump() async {
    final maxConcurrent = Settings.instance.get<int>('maxDownload').clamp(1, 5);
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      if (task.canceled) continue;
      _running++;
      _download(task).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  Future<void> _download(DownloadTask task) async {
    task.status = DownloadStatus.downloading;
    task.progress = 0;
    notifyListeners();

    HttpClient? client;
    try {
      var url = task.song.localPath;
      Map<String, String> headers = {};
      String? userAgent;

      if (url == null || url.isEmpty) {
        final record = PluginManager.instance.byPlatform(task.song.platform);
        if (record == null) throw Exception('插件不可用');
        final info = await PluginManager.instance.getMediaSource(record, task.song,
            quality: Settings.instance.get<String>('downloadQuality'));
        if (info?.url == null || info!.url!.isEmpty) throw Exception('无法获取下载地址');
        url = info.url!;
        headers = info.headers;
        userAgent = info.userAgent;
      }

      if (url.startsWith('http://') || url.startsWith('https://')) {
        client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
        final req = await client.getUrl(Uri.parse(url));
        headers.forEach((k, v) => req.headers.set(k, v));
        if (userAgent != null) req.headers.set(HttpHeaders.userAgentHeader, userAgent);
        final resp = await req.close();
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        final ext = _extensionFor(url, resp.headers.contentType?.mimeType);
        final fileName = _safeFileName('${task.song.artist} - ${task.song.title}') + ext;
        final file = File(p.join(AppPaths.downloads.path, fileName));
        final sink = file.openWrite();
        final total = resp.contentLength;
        var received = 0;
        await for (final chunk in resp) {
          if (task.canceled) {
            await sink.close();
            if (await file.exists()) await file.delete();
            return;
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            task.progress = (received / total).clamp(0, 1);
            notifyListeners();
          }
        }
        await sink.close();
        task.path = file.path;
      } else {
        // 本地文件：复制到下载目录
        final src = File(url);
        final ext = p.extension(url);
        final file = File(p.join(AppPaths.downloads.path, _safeFileName('${task.song.artist} - ${task.song.title}') + ext));
        await src.copy(file.path);
        task.path = file.path;
      }

      task.status = DownloadStatus.completed;
      task.progress = 1;
      await MediaCache.instance.setLocalPath(task.song.key, task.path);
      await _persist();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = '$e';
    } finally {
      client?.close(force: true);
      notifyListeners();
    }
  }

  Future<void> cancel(DownloadTask task) async {
    task.canceled = true;
    _queue.remove(task);
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.canceled;
    } else {
      tasks.remove(task);
    }
    notifyListeners();
  }

  Future<void> remove(DownloadTask task) async {
    if (task.path.isNotEmpty) {
      final f = File(task.path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
      await MediaCache.instance.setLocalPath(task.song.key, null);
    }
    tasks.remove(task);
    await _persist();
    notifyListeners();
  }

  Future<void> clearCompleted() async {
    tasks.removeWhere((e) => e.status == DownloadStatus.completed);
    await _persist();
    notifyListeners();
  }

  static String _safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
    final trimmed = sanitized.length > 80 ? sanitized.substring(0, 80) : sanitized;
    return trimmed.isEmpty ? 'audio_${DateTime.now().millisecondsSinceEpoch}' : trimmed;
  }

  static String _extensionFor(String url, String? mime) {
    final fromUrl = p.extension(Uri.tryParse(url)?.path ?? '');
    if (fromUrl.isNotEmpty && fromUrl.length <= 6) return fromUrl;
    final m = (mime ?? '').toLowerCase();
    if (m.contains('mpeg') || m.contains('mp3')) return '.mp3';
    if (m.contains('flac')) return '.flac';
    if (m.contains('mp4') || m.contains('m4a')) return '.m4a';
    if (m.contains('ogg')) return '.ogg';
    if (m.contains('wav')) return '.wav';
    return '.mp3';
  }

  Map<String, dynamic> exportData() => {
        'tasks': tasks.where((e) => e.status == DownloadStatus.completed).map((e) => {
              'song': e.song.toJson(),
              'path': e.path,
            }).toList()
      };
}
