import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'settings.dart';

class LocalLibrary extends ChangeNotifier {
  LocalLibrary._();
  static final LocalLibrary instance = LocalLibrary._();

  final List<MusicItem> songs = [];
  final List<String> folders = [];
  bool scanning = false;

  static const _prefsSongs = 'localSongs';
  static const _prefsFolders = 'localFolders';
  static const _exts = {'.mp3', '.flac', '.m4a', '.aac', '.wav', '.ogg', '.opus', '.wma', '.ape'};

  Future<void> load() async {
    folders
      ..clear()
      ..addAll((PrefStore.instance.getJsonList(_prefsFolders)).map((e) => e.toString()));
    final raw = PrefStore.instance.getJsonList(_prefsSongs);
    songs
      ..clear()
      ..addAll(raw.whereType<Map>().map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e))));
    notifyListeners();
  }

  Future<void> addFolder(String folder) async {
    if (!folders.contains(folder)) {
      folders.add(folder);
      await PrefStore.instance.setJson(_prefsFolders, folders);
      notifyListeners();
    }
  }

  Future<void> removeFolder(String folder) async {
    folders.remove(folder);
    await PrefStore.instance.setJson(_prefsFolders, folders);
    await rescan();
  }

  Future<int> rescan({void Function(int found, String name)? onProgress}) async {
    if (scanning) return 0;
    scanning = true;
    final found = <MusicItem>[];
    final seen = <String>{};
    try {
      for (final folder in folders) {
        final dir = Directory(folder);
        if (!await dir.exists()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final ext = p.extension(entity.path).toLowerCase();
          if (!_exts.contains(ext)) continue;
          if (seen.contains(entity.path)) continue;
          seen.add(entity.path);
          final item = await _readItem(entity);
          if (item != null) found.add(item);
          onProgress?.call(found.length, p.basename(entity.path));
        }
      }
      songs
        ..clear()
        ..addAll(found);
      songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      await PrefStore.instance.setJson(_prefsSongs, songs.map((e) => e.toJson()).toList());
      notifyListeners();
      return songs.length;
    } finally {
      scanning = false;
    }
  }

  Future<MusicItem?> _readItem(File file) async {
    AudioMetadata? meta;
    try {
      meta = readMetadata(file, getImage: true);
    } catch (_) {}
    final base = p.basenameWithoutExtension(file.path);
    String title = (meta?.title ?? '').trim();
    String artist = (meta?.artist ?? '').trim();
    String album = (meta?.album ?? '').trim();
    if (title.isEmpty) {
      // 常见命名：歌手 - 歌名
      final parts = base.split(' - ');
      if (parts.length >= 2) {
        artist = parts.first.trim();
        title = parts.sublist(1).join(' - ').trim();
      } else {
        title = base;
      }
    }

    String artwork = '';
    final pictures = meta?.pictures ?? const [];
    if (pictures.isNotEmpty) {
      final pic = pictures.first;
      final hash = sha1.convert('${file.path}${file.lastModifiedSync().millisecondsSinceEpoch}'.codeUnits).toString();
      final out = File(p.join(AppPaths.covers.path, '$hash.img'));
      if (!await out.exists()) {
        try {
          await out.writeAsBytes(pic.bytes);
          artwork = out.path;
        } catch (_) {}
      } else {
        artwork = out.path;
      }
    }

    final duration = meta?.duration?.inSeconds ?? 0;
    return MusicItem({
      'id': file.path,
      'platform': 'local',
      'title': title,
      'artist': artist,
      'album': album,
      'artwork': artwork,
      'duration': duration,
      r'$localPath': file.path,
      r'$local': true,
    });
  }

  Future<void> clear() async {
    songs.clear();
    folders.clear();
    await PrefStore.instance.setJson(_prefsSongs, []);
    await PrefStore.instance.setJson(_prefsFolders, []);
    notifyListeners();
  }
}
