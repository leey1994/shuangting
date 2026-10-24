import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/audio_cache.dart';
import 'data/download_manager.dart';
import 'data/kg_api.dart';
import 'data/store.dart';
import 'data/update_service.dart';
import 'dev_tools.dart';
import 'player/player_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 840),
      minimumSize: Size(980, 640),
      center: true,
      title: '爽听',
      backgroundColor: Color(0xFF0A0C12),
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    JustAudioMediaKit.ensureInitialized();
  }

  if (Platform.isAndroid) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.kugou.android.channel.audio',
      androidNotificationChannelName: '爽听播放',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    );
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
  }

  final settings = await SettingsModel.load();
  final library = await LibraryModel.load();
  final api = KgApi(cookie: settings.cookie);
  final cache = AudioCache(api, settings);
  final player = PlayerController(api, cache, library, settings);
  final downloads = DownloadManager(api, cache, library, settings);
  final updates = UpdateService();


  if (kDebugMode) {
    debugPrint('爽听启动 · 音质=${settings.quality} · 平台=${Platform.operatingSystem}');
  }

  registerDevTools(settings: settings, player: player, api: api, library: library);

  runApp(ShuangTingApp(
    settings: settings,
    library: library,
    player: player,
    downloads: downloads,
    updates: updates,
    api: api,
    cache: cache,
  ));
  debugPrint('RUNNAPP DONE');
}
