import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'data/kg_api.dart';
import 'data/store.dart';
import 'player/player_controller.dart';
import 'ui/pages/comments_page.dart';
import 'ui/pages/shell.dart';

/// 仅调试/性能分析模式下注册的本地截图辅助接口，发布版不会包含。
void registerDevTools({
  required SettingsModel settings,
  required PlayerController player,
  required KgApi api,
  required LibraryModel library,
}) {
  if (!kDebugMode && !kProfileMode) return;

  developer.registerExtension('ext.shuangting.demo', (method, params) async {
    settings.onboarded = true;
    settings.themeMode = params['mode'] ?? 'dark';
    settings.accent = params['accent'] ?? 'coral';
    settings.deviceMode = params['device'] ?? 'phone';
    if (params['player'] != null) settings.playerStyle = params['player']!;
    return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true}));
  });

  developer.registerExtension('ext.shuangting.size', (method, params) async {
    if (Platform.isWindows) {
      final w = double.tryParse(params['w'] ?? '') ?? 1280;
      final h = double.tryParse(params['h'] ?? '') ?? 840;
      await windowManager.setSize(Size(w, h));
      await windowManager.setPosition(const Offset(40, 40));
    }
    return developer.ServiceExtensionResponse.result('{"ok":true}');
  });

  developer.registerExtension('ext.shuangting.checkin', (method, params) async {
    settings.onboarded = true;
    await settings.signInToday();
    return developer.ServiceExtensionResponse.result('{"ok":true}');
  });

  developer.registerExtension('ext.shuangting.seed', (method, params) async {
    final songs = await api.searchSongs(params['q'] ?? '热门歌曲');
    for (final s in songs.take(10)) {
      if (!library.favoriteHashes.contains(s.hash)) await library.toggleFavorite(s);
      await library.addHistory(s);
    }
    return developer.ServiceExtensionResponse.result(
        jsonEncode({'ok': true, 'count': songs.length}));
  });

  developer.registerExtension('ext.shuangting.preview', (method, params) async {
    final songs = await api.searchSongs(params['q'] ?? '晴天');
    final song = songs.firstWhere((s) => s.cover.isNotEmpty, orElse: () => songs.first);
    await player.previewSong(song);
    return developer.ServiceExtensionResponse.result(
        jsonEncode({'ok': true, 'title': song.title, 'lyrics': player.lyric?.lines.length ?? 0}));
  });

  developer.registerExtension('ext.shuangting.tab', (method, params) async {
    shellTab.value = int.tryParse(params['i'] ?? '') ?? 0;
    return developer.ServiceExtensionResponse.result('{"ok":true}');
  });

  developer.registerExtension('ext.shuangting.nav', (method, params) async {
    final route = params['route'] ?? '/';
    Object? args;
    final raw = params['args'];
    if (raw != null && raw.isNotEmpty) {
      try {
        args = jsonDecode(raw);
      } catch (_) {}
    }
    appNavigatorKey.currentState?.pushNamed(route, arguments: args);
    return developer.ServiceExtensionResponse.result(jsonEncode({'ok': true, 'route': route}));
  });

  developer.registerExtension('ext.shuangting.pop', (method, params) async {
    appNavigatorKey.currentState?.maybePop();
    return developer.ServiceExtensionResponse.result('{"ok":true}');
  });

  developer.registerExtension('ext.shuangting.play', (method, params) async {
    final query = params['q'] ?? '晴天';
    final songs = await api.searchSongs(query);
    if (songs.isEmpty) {
      return developer.ServiceExtensionResponse.result('{"ok":false,"error":"no songs"}');
    }
    for (final s in songs.take(6)) {
      final resolved = await api.resolveAudio(s, settings.quality);
      if (resolved != null) {
        await player.playSong(s, newQueue: songs);
        return developer.ServiceExtensionResponse.result(
            jsonEncode({'ok': true, 'title': s.title, 'quality': resolved.quality}));
      }
    }
    return developer.ServiceExtensionResponse.result('{"ok":false,"error":"no source"}');
  });

  developer.registerExtension('ext.shuangting.comments', (method, params) async {
    final fallback = await api.searchSongs('晴天');
    final song = player.current ?? (fallback.isEmpty ? null : fallback.first);
    if (song != null) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => CommentsPage(song: song)),
      );
    }
    return developer.ServiceExtensionResponse.result('{"ok":true}');
  });
}
