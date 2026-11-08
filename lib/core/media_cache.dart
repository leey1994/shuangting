import 'models.dart';
import 'settings.dart';

/// 歌曲的本地附加信息：下载路径、本地歌词、歌词关联。
class MediaCache {
  MediaCache._();
  static final MediaCache instance = MediaCache._();

  final Map<String, Map<String, dynamic>> _data = {};
  final Map<String, String> _lyricAssoc = {};
  final Map<String, Map<String, dynamic>> _assocItems = {};

  static const _prefsData = 'mediaCache';
  static const _prefsAssoc = 'lyricAssoc';

  Future<void> load() async {
    final raw = PrefStore.instance.getJson(_prefsData);
    _data
      ..clear()
      ..addAll(raw.map((k, v) => MapEntry(k, v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{})));
    final assoc = PrefStore.instance.getJson(_prefsAssoc);
    _lyricAssoc
      ..clear()
      ..addAll(assoc.map((k, v) => MapEntry(k, v.toString())));
    final assocItems = PrefStore.instance.getJson('lyricAssocItems');
    _assocItems
      ..clear()
      ..addAll(assocItems.map((k, v) => MapEntry(k, v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{})));
  }

  Future<void> _persist() => PrefStore.instance.setJson(_prefsData, _data);

  Map<String, dynamic>? _entry(String key) => _data[key];
  Map<String, dynamic> _ensure(String key) => _data.putIfAbsent(key, () => {});

  String? localPath(String key) => _entry(key)?['localPath']?.toString();

  Future<void> setLocalPath(String key, String? path) async {
    final e = _ensure(key);
    if (path == null || path.isEmpty) {
      e.remove('localPath');
    } else {
      e['localPath'] = path;
    }
    await _persist();
  }

  String? localLyric(String key) => _entry(key)?['lyric']?.toString();

  Future<void> setLocalLyric(String key, String? text) async {
    final e = _ensure(key);
    if (text == null || text.isEmpty) {
      e.remove('lyric');
    } else {
      e['lyric'] = text;
    }
    await _persist();
  }

  double lyricOffset(String key) {
    final v = _entry(key)?['lyricOffset'];
    if (v is num) return v.toDouble();
    return 0;
  }

  Future<void> setLyricOffset(String key, double offset) async {
    _ensure(key)['lyricOffset'] = offset;
    await _persist();
  }

  /// 歌词关联：把 [fromKey] 的歌词指向 [target]；支持链式 A→B→C。
  Future<void> associateLyric(String fromKey, MusicItem target) async {
    final toKey = target.key;
    if (fromKey == toKey) return;
    var cur = toKey;
    var guard = 0;
    while (cur.isNotEmpty && guard++ < 50) {
      if (cur == fromKey) return;
      cur = _lyricAssoc[cur] ?? '';
    }
    _lyricAssoc[fromKey] = toKey;
    _assocItems[toKey] = target.toJson();
    await PrefStore.instance.setJson(_prefsAssoc, _lyricAssoc);
    await PrefStore.instance.setJson('lyricAssocItems', _assocItems);
  }

  Future<void> removeAssociation(String key) async {
    _lyricAssoc.remove(key);
    await PrefStore.instance.setJson(_prefsAssoc, _lyricAssoc);
  }

  MusicItem? associatedItem(String key) {
    final raw = _assocItems[key];
    return raw == null ? null : MusicItem.fromJson(raw);
  }

  String? cachedLyric(String key) => _entry(key)?['rawLyric']?.toString();

  Future<void> setCachedLyric(String key, String? text) async {
    final e = _ensure(key);
    if (text == null || text.isEmpty) {
      e.remove('rawLyric');
    } else {
      e['rawLyric'] = text;
    }
    await _persist();
  }

  bool get hasAssociations => _lyricAssoc.isNotEmpty;
  Map<String, String> get assocItemsRaw =>
      _assocItems.map((k, v) => MapEntry(k, (v['title'] ?? v['id'] ?? '').toString()));

  Map<String, String> get associations => Map<String, String>.from(_lyricAssoc);

  String resolveLyricTarget(String key) {
    var cur = key;
    var guard = 0;
    while (guard++ < 50) {
      final next = _lyricAssoc[cur];
      if (next == null || next.isEmpty) break;
      cur = next;
    }
    return cur;
  }

  Future<void> clear() async {
    _data.clear();
    _lyricAssoc.clear();
    await _persist();
    await PrefStore.instance.setJson(_prefsAssoc, _lyricAssoc);
  }

  Map<String, dynamic> exportData() => {
        'data': _data,
        'assoc': _lyricAssoc,
        'assocItems': _assocItems,
      };

  Future<void> importData(Map<String, dynamic> json) async {
    final data = json['data'];
    if (data is Map) {
      _data
        ..clear()
        ..addAll(data.map((k, v) => MapEntry(k.toString(), v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{})));
    }
    final assoc = json['assoc'];
    if (assoc is Map) {
      _lyricAssoc
        ..clear()
        ..addAll(assoc.map((k, v) => MapEntry(k.toString(), v.toString())));
    }
    final assocItems = json['assocItems'];
    if (assocItems is Map) {
      _assocItems
        ..clear()
        ..addAll(assocItems.map((k, v) => MapEntry(k.toString(), v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{})));
    }
    await _persist();
    await PrefStore.instance.setJson(_prefsAssoc, _lyricAssoc);
    await PrefStore.instance.setJson('lyricAssocItems', _assocItems);
  }
}
