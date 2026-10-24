import 'dart:io';

import 'package:flutter/foundation.dart';

import 'audio_cache.dart';
import 'kg_api.dart';
import 'models.dart';
import 'store.dart';

class DownloadTask {
  final Song song;
  String quality;
  double progress;
  int received;
  int total;
  String? error;
  bool done;

  DownloadTask({
    required this.song,
    required this.quality,
    this.progress = 0,
    this.received = 0,
    this.total = 0,
    this.error,
    this.done = false,
  });
}

class DownloadManager extends ChangeNotifier {
  final KgApi api;
  final AudioCache cache;
  final LibraryModel library;
  final SettingsModel settings;
  final Map<String, DownloadTask> tasks = {};

  DownloadManager(this.api, this.cache, this.library, this.settings);

  bool isActive(String hash) {
    final t = tasks[hash];
    return t != null && !t.done && t.error == null;
  }

  Future<void> enqueue(Song song, {String? quality}) async {
    if (tasks.containsKey(song.hash) && !tasks[song.hash]!.done) return;
    final q = quality ?? settings.quality;
    final task = DownloadTask(song: song, quality: q);
    tasks[song.hash] = task;
    notifyListeners();
    try {
      final resolved = await api.resolveAudio(song, q);
      if (resolved == null) throw KgException('该歌曲暂无可用音源');
      task.quality = resolved.quality;
      final file = await cache.download(
        song,
        resolved.quality,
        url: resolved.url,
        onProgress: (received, total) {
          task.received = received;
          task.total = total;
          task.progress = total > 0 ? received / total : 0;
          notifyListeners();
        },
      );
      task.done = true;
      task.progress = 1;
      await library.addDownload(DownloadRecord(
        song: song,
        quality: resolved.quality,
        size: await file.length(),
        path: file.path,
        time: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (e) {
      task.error = e is KgException ? e.message : '下载失败';
    }
    notifyListeners();
  }

  Future<void> remove(Song song) async {
    tasks.remove(song.hash);
    await library.removeDownload(song.hash);
    notifyListeners();
  }

  void clearFinished() {
    tasks.removeWhere((k, v) => v.done || v.error != null);
    notifyListeners();
  }

  Future<void> openFolder() async {
    final dir = await AppPaths.downloadDir();
    if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
    }
  }
}
