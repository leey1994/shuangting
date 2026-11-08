import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'download_service.dart';
import 'library_store.dart';
import 'media_cache.dart';
import 'models.dart';
import 'plugin/plugin_manager.dart';
import 'plugin/plugin_runtime.dart';
import 'player/player_service.dart';
import 'app_info.dart';
import 'settings.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const fileName = 'shuangting-backup.json';

  Future<Map<String, dynamic>> buildBackup() async {
    final plugins = <Map<String, dynamic>>[];
    for (final record in PluginManager.instance.records) {
      try {
        final file = pluginFile(record.file);
        if (!await file.exists()) continue;
        plugins.add({
          'record': record.toJson(),
          'source': await file.readAsString(),
        });
      } catch (_) {}
    }
    return {
      'app': 'shuangting',
      'schema': 1,
      'version': AppInfo.version,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': Settings.instance.exportAll(),
      'library': LibraryStore.instance.exportData(),
      'mediaCache': MediaCache.instance.exportData(),
      'downloads': DownloadService.instance.exportData(),
      'players': PlayerService.instance.exportState(),
      'plugins': plugins,
    };
  }

  Future<void> applyBackup(Map<String, dynamic> data) async {
    if (data['app'] != 'shuangting') {
      throw Exception('不是爽听备份文件');
    }
    final settings = data['settings'];
    if (settings is Map) {
      await Settings.instance.importAll(Map<String, dynamic>.from(settings));
    }
    final library = data['library'];
    if (library is Map) {
      await LibraryStore.instance.importData(Map<String, dynamic>.from(library));
    }
    final mediaCache = data['mediaCache'];
    if (mediaCache is Map) {
      await MediaCache.instance.importData(Map<String, dynamic>.from(mediaCache));
    }
    final players = data['players'];
    if (players is Map) {
      await PlayerService.instance.restoreState(Map<String, dynamic>.from(players));
    }

    final plugins = data['plugins'];
    if (plugins is List) {
      for (final entry in plugins.whereType<Map>()) {
        final source = entry['source']?.toString() ?? '';
        if (source.isEmpty) continue;
        try {
          final record = await PluginManager.instance.installSource(source);
          final saved = entry['record'];
          if (saved is Map) {
            final meta = PluginRecord.fromJson(Map<String, dynamic>.from(saved));
            record.enabled = meta.enabled;
            record.variables = meta.variables;
            if (meta.supportedSearchType.isNotEmpty) {
              record.supportedSearchType = meta.supportedSearchType;
            }
          }
        } catch (e) {
          debugPrint('[backup] plugin restore failed: $e');
        }
      }
      notifyPluginChange();
    }
  }

  void notifyPluginChange() {
    PluginManager.instance.touch();
  }

  String encodeBackup(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);

  // ---------------- WebDAV ----------------

  Uri _webdavUri() {
    final base = Settings.instance.get<String>('webdavUrl').trim();
    if (base.isEmpty) throw Exception('未配置 WebDAV 地址');
    var url = base.endsWith('/') ? base : '$base/';
    return Uri.parse('$url$fileName');
  }

  Map<String, String> _authHeaders() {
    final user = Settings.instance.get<String>('webdavUsername');
    final pass = Settings.instance.get<String>('webdavPassword');
    final token = base64Encode(utf8.encode('$user:$pass'));
    return {'Authorization': 'Basic $token'};
  }

  Future<bool> testConnection() async {
    final base = Settings.instance.get<String>('webdavUrl').trim();
    if (base.isEmpty) return false;
    final uri = Uri.parse(base.endsWith('/') ? base : '$base/');
    try {
      final req = http.Request('PROPFIND', uri)
        ..headers.addAll({
          ..._authHeaders(),
          'Depth': '0',
        });
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      return streamed.statusCode == 207 || streamed.statusCode == 200 || streamed.statusCode == 301;
    } catch (_) {
      return false;
    }
  }

  Future<void> uploadToWebdav() async {
    final data = await buildBackup();
    final body = utf8.encode(encodeBackup(data));
    final res = await http
        .put(_webdavUri(), headers: {..._authHeaders(), 'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('上传失败 HTTP ${res.statusCode}');
    }
  }

  Future<void> downloadFromWebdav() async {
    final res = await http.get(_webdavUri(), headers: _authHeaders()).timeout(const Duration(seconds: 45));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('下载失败 HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    if (decoded is! Map) throw Exception('备份格式错误');
    await applyBackup(Map<String, dynamic>.from(decoded));
  }

  // ---------------- 本地文件 ----------------

  Future<String> exportToPath(String path) async {
    final data = await buildBackup();
    final file = File(path);
    await file.writeAsString(encodeBackup(data));
    return file.path;
  }

  Future<void> importFromPath(String path) async {
    final text = await File(path).readAsString();
    final decoded = jsonDecode(text);
    if (decoded is! Map) throw Exception('备份格式错误');
    await applyBackup(Map<String, dynamic>.from(decoded));
  }

  String digest(String text) => sha1.convert(utf8.encode(text)).toString();
}
