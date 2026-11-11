import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/legacy.dart' as wm;

import 'app.dart';
import 'core/app_info.dart';
import 'core/desktop/desktop_tray.dart';
import 'core/download_service.dart';
import 'core/library_store.dart';
import 'core/local_library.dart';
import 'core/media_cache.dart';
import 'core/music_audio_handler.dart';
import 'core/player/player_service.dart';
import 'core/plugin/plugin_manager.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await AppPaths.init();
  await Settings.instance.load();
  await PrefStore.instance.ensure();
  await AppInfo.load();

  await Future.wait([
    PluginManager.instance.load(),
    LibraryStore.instance.load(),
    MediaCache.instance.load(),
    DownloadService.instance.load(),
    LocalLibrary.instance.load(),
  ]);
  await PlayerService.instance.init();
  await PlayerService.instance.setSpeed(Settings.instance.get<double>('playSpeed'));
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await initMusicAudioService();
    } catch (e) {
      debugPrint('[audio_service] init failed: $e');
    }
  }

  if (!kIsWeb && Platform.isWindows) {
    await wm.windowManager.ensureInitialized();
    const options = wm.WindowOptions(
      size: Size(1180, 820),
      minimumSize: Size(420, 640),
      center: true,
      title: '爽听',
      backgroundColor: Colors.transparent,
    );
    await wm.windowManager.waitUntilReadyToShow(options, () async {
      await wm.windowManager.show();
      await wm.windowManager.focus();
    });
  }

  runApp(const ShuangTingApp());

  // 托盘在窗口就绪、首帧渲染后再注册，避免和窗口创建抢消息循环。
  if (!kIsWeb && Platform.isWindows) {
    await Future<void>.delayed(const Duration(seconds: 2));
    await DesktopTray.instance.init();
  }
}
