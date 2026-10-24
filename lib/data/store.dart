import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

const accentChoices = <String, Color>{
  'coral': Color(0xFFFF4D6D),
  'mint': Color(0xFF35D6A4),
  'violet': Color(0xFF8B6CFF),
  'amber': Color(0xFFFFA62B),
  'ocean': Color(0xFF3AA0FF),
  'rose': Color(0xFFF25C9C),
};

class SettingsModel extends ChangeNotifier {
  final SharedPreferences _prefs;
  SettingsModel(this._prefs);

  static Future<SettingsModel> load() async =>
      SettingsModel(await SharedPreferences.getInstance());

  T _get<T>(String key, T fallback) {
    final v = _prefs.get(key);
    return v is T ? v : fallback;
  }

  bool get onboarded => _get('onboarded', false);
  set onboarded(bool v) => _set('onboarded', v);

  String get themeMode => _get('themeMode', 'dark');
  set themeMode(String v) => _set('themeMode', v);

  String get accent => _get('accent', 'coral');
  set accent(String v) => _set('accent', v);
  Color get accentColor => accentChoices[accent] ?? accentChoices['coral']!;

  String get quality => _get('quality', '320');
  set quality(String v) => _set('quality', v);

  bool get autoCache => _get('autoCache', true);
  set autoCache(bool v) => _set('autoCache', v);

  int get cacheLimitMb => _get('cacheLimitMb', 2048);
  set cacheLimitMb(int v) => _set('cacheLimitMb', v);

  bool get dragPause => _get('dragPause', true);
  set dragPause(bool v) => _set('dragPause', v);

  String get playerStyle => _get('playerStyle', 'vinyl');
  set playerStyle(String v) => _set('playerStyle', v);

  double get lyricScale => _get('lyricScale', 1.0);
  set lyricScale(double v) => _set('lyricScale', v);

  bool get glow => _get('glow', true);
  set glow(bool v) => _set('glow', v);

  bool get flowBg => _get('flowBg', true);
  set flowBg(bool v) => _set('flowBg', v);

  String get deviceMode => _get('deviceMode', 'auto');
  set deviceMode(String v) => _set('deviceMode', v);

  bool get autoSignIn => _get('autoSignIn', true);
  set autoSignIn(bool v) => _set('autoSignIn', v);

  bool get autoUpdate => _get('autoUpdate', true);
  set autoUpdate(bool v) => _set('autoUpdate', v);

  String get nickname => _get('nickname', '爽听用户');
  set nickname(String v) => _set('nickname', v);

  String get cookie => _get('cookie', '');
  set cookie(String v) => _set('cookie', v);

  bool get desktopLyric => _get('desktopLyric', false);
  set desktopLyric(bool v) => _set('desktopLyric', v);

  bool get eqEnabled => _get('eqEnabled', false);
  set eqEnabled(bool v) => _set('eqEnabled', v);

  String get eqPreset => _get('eqPreset', '默认');
  set eqPreset(String v) => _set('eqPreset', v);

  double get speed => _get('speed', 1.0);
  set speed(double v) => _set('speed', v);

  List<String> get searchHistory {
    final raw = _prefs.getString('searchHistory');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  void addSearchHistory(String kw) {
    if (kw.trim().isEmpty) return;
    final list = searchHistory..removeWhere((e) => e == kw);
    list.insert(0, kw);
    if (list.length > 12) list.removeRange(12, list.length);
    _prefs.setString('searchHistory', jsonEncode(list));
    notifyListeners();
  }

  void clearSearchHistory() {
    _prefs.remove('searchHistory');
    notifyListeners();
  }

  List<String> get signInDates {
    final raw = _prefs.getString('signInDates');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  bool get signedInToday {
    final today = DateTime.now();
    final key = _dateKey(today);
    return signInDates.contains(key);
  }

  int get signInStreak {
    final set = signInDates.toSet();
    if (set.isEmpty) return 0;
    var cursor = DateTime.now();
    if (!set.contains(_dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (set.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get signInTotal => signInDates.length;

  Future<void> signInToday() async {
    if (signedInToday) return;
    final list = signInDates..add(_dateKey(DateTime.now()));
    await _prefs.setString('signInDates', jsonEncode(list));
    notifyListeners();
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _set(String key, Object value) async {
    if (value is bool) await _prefs.setBool(key, value);
    if (value is int) await _prefs.setInt(key, value);
    if (value is double) await _prefs.setDouble(key, value);
    if (value is String) await _prefs.setString(key, value);
    notifyListeners();
  }

  Future<void> resetAll() async {
    final keep = _prefs.getKeys().where((k) => !k.startsWith('st_')).toList();
    for (final k in _prefs.getKeys().toList()) {
      if (!keep.contains(k)) await _prefs.remove(k);
    }
    notifyListeners();
  }
}

class LocalPlaylist {
  final String id;
  final String name;
  final List<Song> songs;
  final int createdAt;

  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.songs,
    required this.createdAt,
  });

  LocalPlaylist copyWith({String? name, List<Song>? songs}) => LocalPlaylist(
        id: id,
        name: name ?? this.name,
        songs: songs ?? this.songs,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songs': songs.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> j) => LocalPlaylist(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '我的歌单').toString(),
        songs: (j['songs'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );
}

class DownloadRecord {
  final Song song;
  final String quality;
  final int size;
  final String path;
  final int time;

  const DownloadRecord({
    required this.song,
    required this.quality,
    required this.size,
    required this.path,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'song': song.toJson(),
        'quality': quality,
        'size': size,
        'path': path,
        'time': time,
      };

  factory DownloadRecord.fromJson(Map<String, dynamic> j) => DownloadRecord(
        song: Song.fromJson(Map<String, dynamic>.from(j['song'] as Map)),
        quality: (j['quality'] ?? '').toString(),
        size: (j['size'] as num?)?.toInt() ?? 0,
        path: (j['path'] ?? '').toString(),
        time: (j['time'] as num?)?.toInt() ?? 0,
      );
}

class LibraryModel extends ChangeNotifier {
  final SharedPreferences _prefs;
  LibraryModel(this._prefs) {
    _load();
  }

  static Future<LibraryModel> load() async =>
      LibraryModel(await SharedPreferences.getInstance());

  final List<Song> favorites = [];
  final List<Song> history = [];
  final List<LocalPlaylist> playlists = [];
  final List<DownloadRecord> downloads = [];
  final List<Song> local = [];
  final Map<String, int> playCounts = {};
  final Map<String, int> positions = {};
  int listenSeconds = 0;

  Set<String> get favoriteHashes => favorites.map((e) => e.hash).toSet();

  bool isFavorite(Song s) => favoriteHashes.contains(s.hash);

  void _load() {
    favorites
      ..clear()
      ..addAll(_readSongs('lib_favorites'));
    history
      ..clear()
      ..addAll(_readSongs('lib_history'));
    playlists
      ..clear()
      ..addAll(_readJsonList('lib_playlists')
          .map((e) => LocalPlaylist.fromJson(Map<String, dynamic>.from(e))));
    downloads
      ..clear()
      ..addAll(_readJsonList('lib_downloads')
          .map((e) => DownloadRecord.fromJson(Map<String, dynamic>.from(e))));
    local
      ..clear()
      ..addAll(_readSongs('lib_local'));
    final pc = _prefs.getString('lib_playCounts');
    if (pc != null) {
      try {
        (jsonDecode(pc) as Map).forEach((k, v) {
          playCounts[k.toString()] = (v as num).toInt();
        });
      } catch (_) {}
    }
    final pos = _prefs.getString('lib_positions');
    if (pos != null) {
      try {
        (jsonDecode(pos) as Map).forEach((k, v) {
          positions[k.toString()] = (v as num).toInt();
        });
      } catch (_) {}
    }
    listenSeconds = _prefs.getInt('lib_listenSeconds') ?? 0;
  }

  List<Song> _readSongs(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _readJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveSongs(String key, List<Song> list) async {
    await _prefs.setString(key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> toggleFavorite(Song song) async {
    if (favoriteHashes.contains(song.hash)) {
      favorites.removeWhere((e) => e.hash == song.hash);
    } else {
      favorites.insert(0, song);
    }
    await _saveSongs('lib_favorites', favorites);
    notifyListeners();
  }

  Future<void> removeFavorites(Iterable<String> hashes) async {
    favorites.removeWhere((e) => hashes.contains(e.hash));
    await _saveSongs('lib_favorites', favorites);
    notifyListeners();
  }

  Future<void> addHistory(Song song) async {
    history.removeWhere((e) => e.hash == song.hash);
    history.insert(0, song);
    if (history.length > 300) history.removeRange(300, history.length);
    playCounts[song.hash] = (playCounts[song.hash] ?? 0) + 1;
    await _saveSongs('lib_history', history);
    await _prefs.setString('lib_playCounts', jsonEncode(playCounts));
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _saveSongs('lib_history', history);
    notifyListeners();
  }

  Future<void> addListenSeconds(int seconds) async {
    listenSeconds += seconds;
    await _prefs.setInt('lib_listenSeconds', listenSeconds);
  }

  Future<void> savePosition(String hash, int ms) async {
    if (ms <= 0) return;
    positions[hash] = ms;
    if (positions.length > 200) {
      final first = positions.keys.first;
      positions.remove(first);
    }
    await _prefs.setString('lib_positions', jsonEncode(positions));
  }

  int positionOf(String hash) => positions[hash] ?? 0;

  Future<LocalPlaylist> createPlaylist(String name, [List<Song> songs = const []]) async {
    final pl = LocalPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? '我的歌单' : name.trim(),
      songs: List.of(songs),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    playlists.insert(0, pl);
    await _savePlaylists();
    notifyListeners();
    return pl;
  }

  Future<void> deletePlaylist(String id) async {
    playlists.removeWhere((e) => e.id == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> renamePlaylist(String id, String name) async {
    final i = playlists.indexWhere((e) => e.id == id);
    if (i < 0) return;
    playlists[i] = playlists[i].copyWith(name: name);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addToPlaylist(String id, List<Song> songs) async {
    final i = playlists.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final existing = playlists[i].songs.map((e) => e.hash).toSet();
    final merged = List<Song>.of(playlists[i].songs);
    for (final s in songs) {
      if (!existing.contains(s.hash)) merged.add(s);
    }
    playlists[i] = playlists[i].copyWith(songs: merged);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> removeFromPlaylist(String id, String hash) async {
    final i = playlists.indexWhere((e) => e.id == id);
    if (i < 0) return;
    playlists[i] = playlists[i].copyWith(
        songs: playlists[i].songs.where((e) => e.hash != hash).toList());
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> _savePlaylists() async {
    await _prefs.setString(
        'lib_playlists', jsonEncode(playlists.map((e) => e.toJson()).toList()));
  }

  Future<void> addDownload(DownloadRecord record) async {
    downloads.removeWhere((e) => e.song.hash == record.song.hash);
    downloads.insert(0, record);
    await _prefs.setString(
        'lib_downloads', jsonEncode(downloads.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> removeDownload(String hash, {bool deleteFile = true}) async {
    final i = downloads.indexWhere((e) => e.song.hash == hash);
    if (i >= 0) {
      final rec = downloads[i];
      if (deleteFile) {
        try {
          final f = File(rec.path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      downloads.removeAt(i);
      await _prefs.setString(
          'lib_downloads', jsonEncode(downloads.map((e) => e.toJson()).toList()));
      notifyListeners();
    }
  }

  bool isDownloaded(String hash) => downloads.any((e) => e.song.hash == hash);

  Future<void> addLocalSongs(List<Song> songs) async {
    final existing = local.map((e) => e.hash).toSet();
    for (final s in songs) {
      if (!existing.contains(s.hash)) local.add(s);
    }
    await _saveSongs('lib_local', local);
    notifyListeners();
  }

  Future<void> removeLocalSong(String hash) async {
    local.removeWhere((e) => e.hash == hash);
    await _saveSongs('lib_local', local);
    notifyListeners();
  }

  Future<void> clearLocal() async {
    local.clear();
    await _saveSongs('lib_local', local);
    notifyListeners();
  }

  List<Song> get localSongs {
    final map = <String, Song>{};
    for (final d in downloads) {
      map[d.song.hash] = d.song;
    }
    return map.values.toList();
  }
}

class AppPaths {
  static Directory? _support;
  static Directory? _cacheDir;

  static Future<Directory> support() async {
    _support ??= await getApplicationSupportDirectory();
    return _support!;
  }

  static Future<Directory> cache() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await support();
    final dir = Directory(p.join(base.path, 'audio_cache'));
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {}
    _cacheDir = dir;
    return dir;
  }

  static Future<Directory> downloadDir() async {
    if (Platform.isAndroid) {
      final base = await support();
      final dir = Directory(p.join(base.path, 'downloads'));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    final base = await getDownloadsDirectory() ?? await support();
    final dir = Directory(p.join(base.path, 'ShuangTing'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(value >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
  }

  static String randomId() {
    final r = Random();
    return '${DateTime.now().millisecondsSinceEpoch}${r.nextInt(9999)}';
  }
}
