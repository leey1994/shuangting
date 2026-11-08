import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'settings.dart';

class LibraryStore extends ChangeNotifier {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  final List<Playlist> playlists = [];
  final List<HistoryEntry> history = [];

  static const _prefsPlaylists = 'playlists';
  static const _prefsHistory = 'history';

  Playlist get favorites => playlists.firstWhere(
        (e) => e.id == Playlist.favoritesId,
        orElse: () {
          final p = Playlist(
            id: Playlist.favoritesId,
            name: '我喜欢',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          playlists.insert(0, p);
          return p;
        },
      );

  List<Playlist> get userPlaylists => playlists.where((e) => !e.isFavorites).toList();

  Future<void> load() async {
    final raw = PrefStore.instance.getJsonList(_prefsPlaylists);
    playlists
      ..clear()
      ..addAll(raw.whereType<Map>().map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))));
    if (!playlists.any((e) => e.isFavorites)) {
      playlists.insert(
        0,
        Playlist(
          id: Playlist.favoritesId,
          name: '我喜欢',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    final h = PrefStore.instance.getJsonList(_prefsHistory);
    history
      ..clear()
      ..addAll(h.whereType<Map>().map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e))));
    notifyListeners();
  }

  Future<void> _savePlaylists() async {
    await PrefStore.instance.setJson(_prefsPlaylists, playlists.map((e) => e.toJson()).toList());
  }

  Future<void> _saveHistory() async {
    await PrefStore.instance.setJson(_prefsHistory, history.map((e) => e.toJson()).toList());
  }

  bool isFavorite(MusicItem song) => favorites.songs.any((e) => e.key == song.key);

  Future<bool> toggleFavorite(MusicItem song) async {
    final fav = favorites;
    final idx = fav.songs.indexWhere((e) => e.key == song.key);
    if (idx >= 0) {
      fav.songs.removeAt(idx);
    } else {
      fav.songs.insert(0, song);
    }
    fav.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _savePlaylists();
    notifyListeners();
    return idx < 0;
  }

  Playlist createPlaylist(String name, {String cover = ''}) {
    final p = Playlist(
      id: 'local::${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      name: name,
      cover: cover,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    playlists.add(p);
    _savePlaylists();
    notifyListeners();
    return p;
  }

  Future<void> renamePlaylist(Playlist p, String name) async {
    p.name = name;
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(Playlist p) async {
    if (p.isFavorites) return;
    playlists.removeWhere((e) => e.id == p.id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<int> addSongsToPlaylist(Playlist p, List<MusicItem> songs, {bool dedupe = true}) async {
    var added = 0;
    final existing = p.songs.map((e) => e.key).toSet();
    for (final s in songs) {
      if (dedupe && existing.contains(s.key)) continue;
      p.songs.add(s);
      existing.add(s.key);
      added++;
    }
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _savePlaylists();
    notifyListeners();
    return added;
  }

  Future<void> removeSongAt(Playlist p, int index) async {
    if (index < 0 || index >= p.songs.length) return;
    p.songs.removeAt(index);
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> moveSong(Playlist p, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final s = p.songs.removeAt(oldIndex);
    p.songs.insert(newIndex, s);
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> clearPlaylist(Playlist p) async {
    p.songs.clear();
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addHistory(MusicItem song) async {
    if (song.id.isEmpty) return;
    history.removeWhere((e) => e.song.key == song.key);
    history.insert(0, HistoryEntry(song: song, playedAt: DateTime.now().millisecondsSinceEpoch));
    final maxLen = Settings.instance.get<int>('maxHistoryLen');
    if (history.length > maxLen) history.removeRange(maxLen, history.length);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearAllUserData() async {
    playlists.removeWhere((e) => !e.isFavorites);
    favorites.songs.clear();
    history.clear();
    await _savePlaylists();
    await _saveHistory();
    notifyListeners();
  }

  Map<String, dynamic> exportData() => {
        'playlists': playlists.map((e) => e.toJson()).toList(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  Future<void> importData(Map<String, dynamic> data) async {
    final pls = data['playlists'];
    if (pls is List) {
      playlists
        ..clear()
        ..addAll(pls.whereType<Map>().map((e) => Playlist.fromJson(Map<String, dynamic>.from(e))));
    }
    if (!playlists.any((e) => e.isFavorites)) {
      playlists.insert(
        0,
        Playlist(
          id: Playlist.favoritesId,
          name: '我喜欢',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    final h = data['history'];
    if (h is List) {
      history
        ..clear()
        ..addAll(h.whereType<Map>().map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e))));
    }
    await _savePlaylists();
    await _saveHistory();
    notifyListeners();
  }
}

