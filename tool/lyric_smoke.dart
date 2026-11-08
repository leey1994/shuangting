// 开发期冒烟：真实插件自动跨源匹配歌词。
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:shuangting/core/models.dart';
import 'package:shuangting/core/plugin/plugin_manager.dart';
import 'package:shuangting/core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  await Settings.instance.load();
  await PrefStore.instance.ensure();
  await PluginManager.instance.load();
  await PluginManager.instance.warmup();

  final log = StringBuffer();
  final qq = PluginManager.instance.byPlatform('qq');
  if (qq == null) {
    log.writeln('qq plugin missing');
  } else {
    final res = await PluginManager.instance.search(qq, '周杰伦 晴天', 1, 'music');
    final songs = (res?.data ?? const [])
        .whereType<Map>()
        .map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.title.isNotEmpty)
        .toList();
    log.writeln('songs=${songs.length}');
    if (songs.isNotEmpty) {
      final song = songs.first;
      final lyric = await PluginManager.instance.autoMatchLyric(song);
      log.writeln('song=${song.title} / ${song.displayArtist}');
      log.writeln('lyricLen=${lyric?.length ?? 0}');
      log.writeln('lyricHead=${(lyric ?? '').replaceAll('\n', ' | ').substring(0, (lyric ?? '').length.clamp(0, 160))}');
    }
  }
  File('lyric_smoke_result.txt').writeAsStringSync(log.toString());
  exit(0);
}