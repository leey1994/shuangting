import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'app_info.dart';
import 'settings.dart';

/// GitHub Release 中的一个构建物。
class UpdateAsset {
  const UpdateAsset({required this.name, required this.url, required this.size});
  final String name;
  final String url;
  final int size;

  double get sizeMb => size / (1024 * 1024);
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.asset,
  });

  final String version;
  final String notes;
  final String pageUrl;

  /// 平台对应的可直接安装构建物；为空时只能跳转浏览器。
  final UpdateAsset? asset;
}

/// 从 GitHub Releases 检查并安装更新。
class Updater {
  Updater._();

  static UpdateInfo? _cached;
  static DateTime _checkedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<UpdateInfo?> check({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _cached != null && now.difference(_checkedAt).inMinutes < 30) {
      return _cached;
    }
    try {
      final res = await http.get(
        Uri.parse(AppInfo.latestReleaseApi),
        headers: const {'User-Agent': 'ShuangTing-Updater', 'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map) return null;
      final tag = (json['tag_name'] ?? '').toString();
      final latest = tag.replaceFirst(RegExp(r'^[vV]'), '');
      if (!_isNewer(latest, AppInfo.version)) return null;

      final assets = <UpdateAsset>[];
      final rawAssets = json['assets'];
      if (rawAssets is List) {
        for (final a in rawAssets) {
          if (a is! Map) continue;
          final url = (a['browser_download_url'] ?? '').toString();
          if (url.isEmpty) continue;
          assets.add(UpdateAsset(
            name: (a['name'] ?? '').toString(),
            url: url,
            size: (a['size'] is num) ? (a['size'] as num).toInt() : 0,
          ));
        }
      }

      final info = UpdateInfo(
        version: latest,
        notes: (json['body'] ?? '').toString().trim(),
        pageUrl: (json['html_url'] ?? AppInfo.releasesUrl).toString(),
        asset: _pickAsset(assets),
      );
      _cached = info;
      _checkedAt = now;
      return info;
    } catch (e) {
      debugPrint('[updater] check failed: $e');
      return null;
    }
  }

  static UpdateAsset? _pickAsset(List<UpdateAsset> assets) {
    bool endsWith(String n, String ext) => n.toLowerCase().endsWith(ext);
    if (Platform.isAndroid) {
      final apks = assets.where((a) => endsWith(a.name, '.apk')).toList();
      final abi = _androidAbi();
      for (final a in apks) {
        if (a.name.toLowerCase().contains(abi)) return a;
      }
      // arm64-v8a 是主流；拿不到 ABI 时优先 arm64，再退回第一个。
      for (final a in apks) {
        if (a.name.toLowerCase().contains('arm64')) return a;
      }
      return apks.isEmpty ? null : apks.first;
    }
    return null;
  }

  static String _androidAbi() {
    try {
      // 只能拿到 CPU 架构字符串，够用来匹配资产名。
      final arch = Platform.version.toLowerCase();
      if (arch.contains('arm64') || arch.contains('aarch64')) return 'arm64';
      if (arch.contains('x64') || arch.contains('x86_64')) return 'x86_64';
      return 'armeabi';
    } catch (_) {
      return 'arm64';
    }
  }

  /// 下载到缓存目录，返回本地文件。
  static Future<File> download(UpdateInfo info, {void Function(double progress)? onProgress}) async {
    final asset = info.asset;
    if (asset == null) throw StateError('没有可下载的构建物');
    final dir = Directory(p.join(AppPaths.cache.path, 'update'));
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, asset.name));

    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(asset.url)));
      if (res.statusCode != 200) throw HttpException('下载失败: HTTP ${res.statusCode}');
      final total = res.contentLength ?? asset.size;
      final sink = target.openWrite();
      var received = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
      }
      await sink.flush();
      await sink.close();
      return target;
    } finally {
      client.close();
    }
  }

  /// 交给系统安装器。Android 会弹出安装界面。
  static Future<void> install(File file) async {
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done) {
        throw StateError(result.message.isEmpty ? '无法启动安装器' : result.message);
      }
    } else if (Platform.isWindows) {
      await Process.start(file.path, const [], mode: ProcessStartMode.detached);
    }
  }

  static bool _isNewer(String latest, String current) {
    final a = _parts(latest);
    final b = _parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _parts(String v) =>
      v.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
}
