import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'plugin/plugin_manager.dart';
import 'settings.dart';

/// 每日推荐：从热歌池里按「日期」做种子随机抽 10 首，当天固定。
/// 热歌池来自发现页聚合结果，首次启动没有缓存时后台拉一次榜单补齐。
class DailyRecommendation extends ChangeNotifier {
  DailyRecommendation._();
  static final DailyRecommendation instance = DailyRecommendation._();

  static const _keyPool = 'dailySongPool';
  static const _keySongs = 'dailySongs';
  static const _keyDate = 'dailyDate';
  static const _count = 10;
  static const _poolLimit = 40;

  List<MusicItem> songs = [];
  Future<void>? _pending;

  String get _today {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> ensureToday() {
    final pending = _pending;
    if (pending != null) return pending;
    final future = _ensureToday();
    _pending = future;
    return future.whenComplete(() => _pending = null);
  }

  Future<void> _ensureToday() async {
    final date = _today;
    if (PrefStore.instance.getString(_keyDate) == date) {
      songs = _read(_keySongs);
      if (songs.isNotEmpty) {
        notifyListeners();
        return;
      }
    }
    var pool = _read(_keyPool);
    if (pool.isEmpty) {
      pool = await _fetchHotSongs();
      if (pool.isNotEmpty) await _save(_keyPool, pool);
    }
    songs = _pick(pool);
    await _save(_keySongs, songs);
    await PrefStore.instance.setString(_keyDate, date);
    notifyListeners();
  }

  /// 发现页聚合到新热歌时调用；当天已经抽过就不再改动结果。
  void updatePool(Iterable<MusicItem> hot) {
    final pool = _read(_keyPool);
    final seen = pool.map((e) => e.key).toSet();
    for (final song in hot) {
      if (song.id.isEmpty || !seen.add(song.key)) continue;
      pool.add(song);
    }
    if (pool.isEmpty) return;
    if (pool.length > _poolLimit) {
      pool.removeRange(0, pool.length - _poolLimit);
    }
    unawaited(_save(_keyPool, pool));
  }

  List<MusicItem> _read(String key) => PrefStore.instance
      .getJsonList(key)
      .whereType<Map>()
      .map((e) => MusicItem.fromJson(Map<String, dynamic>.from(e)))
      .where((e) => e.id.isNotEmpty)
      .toList();

  Future<void> _save(String key, List<MusicItem> list) =>
      PrefStore.instance.setJson(key, list.map((e) => e.toJson()).toList());

  List<MusicItem> _pick(List<MusicItem> pool) {
    final list = List<MusicItem>.from(pool);
    list.shuffle(Random(int.tryParse(_today) ?? DateTime.now().millisecondsSinceEpoch));
    return list.take(_count).toList();
  }

  Future<List<MusicItem>> _fetchHotSongs() async {
    final plugins = PluginManager.instance.enabled
        .where((e) => e.methods.contains('getTopLists'))
        .take(3)
        .toList();
    if (plugins.isEmpty) return const [];
    try {
      await PluginManager.instance.warmup(limit: 2).timeout(const Duration(seconds: 6));
    } catch (_) {}
    final result = <MusicItem>[];
    for (final plugin in plugins) {
      try {
        final lists = await PluginManager.instance.getTopLists(plugin);
        SheetItem? first;
        for (final item in lists) {
          if (item is! Map) continue;
          final data = item['data'];
          final raws = data is List ? data : [item];
          for (final raw in raws.whereType<Map>()) {
            final sheet = SheetItem.fromJson(Map<String, dynamic>.from(raw));
            if (sheet.id.isEmpty) continue;
            first = sheet;
            break;
          }
          if (first != null) break;
        }
        if (first == null) continue;
        final detail = await PluginManager.instance.getTopListDetail(plugin, first, 1);
        final data = detail?['musicList'] ?? detail?['data'] ?? detail?['entries'];
        if (data is! List) continue;
        for (final raw in data.whereType<Map>().take(10)) {
          final map = Map<String, dynamic>.from(raw);
          if ((map['platform'] ?? '').toString().isEmpty) map['platform'] = plugin.platform;
          final song = MusicItem.fromJson(map);
          if (song.id.isEmpty) continue;
          result.add(song);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[daily] ${plugin.platform}: $e');
      }
      if (result.length >= 20) break;
    }
    return result;
  }
}
