import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

class UpdateInfo {
  final String version;
  final String notes;
  final String pageUrl;
  final String? androidAsset;
  final String? windowsAsset;

  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    this.androidAsset,
    this.windowsAsset,
  });
}

class UpdateService extends ChangeNotifier {
  static const repo = 'leey1994/shuangting';
  static const repoUrl = 'https://github.com/leey1994/shuangting';
  static const pagesUrl = 'https://leey1994.github.io/shuangting/';
  static const releasesUrl = 'https://github.com/leey1994/shuangting/releases';

  bool checking = false;
  UpdateInfo? available;
  double progress = 0;
  bool downloading = false;
  String? message;

  Future<UpdateInfo?> check() async {
    checking = true;
    message = null;
    notifyListeners();
    try {
      final info = await PackageInfo.fromPlatform();
      final current = _parse(info.version);
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'ShuangTing-Updater',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 404) {
        message = '暂未发布版本';
        return null;
      }
      if (res.statusCode != 200) {
        message = '检查更新失败 (${res.statusCode})';
        return null;
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tag = (data['tag_name'] ?? '').toString();
      final latest = _parse(tag);
      if (!_isNewer(latest, current)) {
        message = '已是最新版本';
        return null;
      }
      String? androidAsset;
      String? windowsAsset;
      final assets = data['assets'];
      if (assets is List) {
        for (final a in assets.whereType<Map>()) {
          final name = (a['name'] ?? '').toString();
          final url = (a['browser_download_url'] ?? '').toString();
          if (url.isEmpty) continue;
          final lower = name.toLowerCase();
          if (lower.endsWith('.apk') && lower.contains('arm64')) {
            androidAsset = url;
          } else if (lower.endsWith('.zip') && lower.contains('windows')) {
            windowsAsset = url;
          }
        }
      }
      available = UpdateInfo(
        version: tag.replaceFirst('v', ''),
        notes: (data['body'] ?? '').toString(),
        pageUrl: (data['html_url'] ?? releasesUrl).toString(),
        androidAsset: androidAsset,
        windowsAsset: windowsAsset,
      );
      notifyListeners();
      return available;
    } catch (_) {
      message = '检查更新失败，请稍后再试';
      return null;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<bool> downloadAndInstall() async {
    final info = available;
    if (info == null) return false;
    final url = Platform.isAndroid
        ? info.androidAsset
        : Platform.isWindows
            ? info.windowsAsset
            : null;
    if (url == null) {
      message = Platform.isAndroid ? '该版本暂未提供安卓安装包' : '该版本暂未提供 Windows 安装包';
      notifyListeners();
      return false;
    }
    downloading = true;
    progress = 0;
    message = '正在下载 ${info.version}…';
    notifyListeners();
    try {
      final temp = Directory(p.join((await Directory.systemTemp).path, 'shuangting_update'));
      if (await temp.exists()) await temp.delete(recursive: true);
      await temp.create(recursive: true);
      final name = Platform.isAndroid ? 'shuangting_update.apk' : 'shuangting_update.zip';
      final file = File(p.join(temp.path, name));
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'ShuangTing-Updater';
      final res = await client.send(req);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        progress = total > 0 ? received / total : 0;
        notifyListeners();
      }
      await sink.close();
      client.close();
      message = '下载完成，准备安装…';
      notifyListeners();

      if (Platform.isAndroid) {
        final result = await OpenFilex.open(file.path);
        message = result.type == ResultType.done ? '已打开安装程序' : '无法启动安装，请允许安装未知来源应用';
        return result.type == ResultType.done;
      }
      if (Platform.isWindows) {
        await _installWindows(file, temp);
        return true;
      }
      return false;
    } catch (e) {
      message = '更新失败：$e';
      return false;
    } finally {
      downloading = false;
      notifyListeners();
    }
  }

  Future<void> _installWindows(File zip, Directory temp) async {
    final extractDir = Directory(p.join(temp.path, 'extracted'));
    await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Expand-Archive -LiteralPath "${zip.path}" -DestinationPath "${extractDir.path}" -Force',
    ]);
    var exe = File(p.join(extractDir.path, 'shuangting.exe'));
    if (!await exe.exists()) {
      await for (final e in extractDir.list(recursive: true)) {
        if (e is File && p.basename(e.path).toLowerCase() == 'shuangting.exe') {
          exe = e;
          break;
        }
      }
    }
    final sourceDir = p.dirname(exe.path);
    final installDir = p.dirname(Platform.resolvedExecutable);
    final bat = File(p.join(temp.path, 'apply_update.bat'));
    await bat.writeAsString('''
@echo off
timeout /t 2 /nobreak >nul
:wait
tasklist /FI "PID eq ${pid}" | find "${pid}" >nul
if not errorlevel 1 (
  timeout /t 1 /nobreak >nul
  goto wait
)
xcopy /E /I /Y "${sourceDir}\\*" "${installDir}\\"
start "" "${Platform.resolvedExecutable}"
del "%~f0"
''');
    await Process.start('cmd', ['/c', bat.path],
        mode: ProcessStartMode.detached, workingDirectory: temp.path);
    await Future.delayed(const Duration(milliseconds: 600));
    exit(0);
  }

  static List<int> _parse(String version) {
    final clean = version.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = clean.split('.').where((e) => e.isNotEmpty).map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  static bool _isNewer(List<int> latest, List<int> current) {
    for (var i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return false;
  }
}
