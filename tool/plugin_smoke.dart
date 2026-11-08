// 开发期冒烟：加载全部插件，真实联网搜索并取一条音源地址。
// 运行：flutter build windows --debug --target=tool/plugin_smoke.dart
//       build\windows\x64\runner\Debug\shuangting.exe
// 结果写入 smoke_result.txt。
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'package:shuangting/core/models.dart';
import 'package:shuangting/core/plugin/plugin_manager.dart';
import 'package:shuangting/core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  await Settings.instance.load();
  await PrefStore.instance.ensure();
  await PluginManager.instance.load();

  final log = StringBuffer();
  final sw = Stopwatch()..start();
  try {
    final r = await http.get(Uri.parse('https://y.qq.com/')).timeout(const Duration(seconds: 15));
    log.writeln('direct-http ${r.statusCode} ${sw.elapsedMilliseconds}ms');
  } catch (e) {
    log.writeln('direct-http FAIL $e');
  }
  for (final record in PluginManager.instance.enabled) {
    await PluginManager.instance.runtimeFor(record);
    if (!record.methods.contains('search')) {
      log.writeln('${record.platform}: 不支持搜索');
      continue;
    }
    final res = await PluginManager.instance.search(record, '周杰伦', 1, 'music');
    final items = res?.data.whereType<Map>().toList() ?? const [];
    log.writeln('${record.platform}: items=${items.length} isEnd=${res?.isEnd}');

    dynamic song;
    for (final raw in items) {
      final m = MusicItem.fromJson(Map<String, dynamic>.from(raw));
      if (m.title.isNotEmpty) {
        song = raw;
        break;
      }
    }
    if (song != null) {
      final m = MusicItem.fromJson(song);
      log.writeln('  first=${m.title} / ${m.displayArtist} / ${m.album}');
      final src = await PluginManager.instance.getMediaSource(record, m);
      log.writeln('  media=${src?.url ?? 'null'}');
      final rt = await PluginManager.instance.runtimeFor(record);
      if (rt != null) {
        final raw = await rt.call('getMediaSource', [m.toJson(), 'standard'], timeout: const Duration(seconds: 30));
        log.writeln('  rawOk=${raw.ok} err=${raw.error} value=${raw.value?.toString().substring(0, (raw.value?.toString().length ?? 0).clamp(0, 200))}');
      }
    }
  }
  File('smoke_result.txt').writeAsStringSync(log.toString());
  exit(0);
}