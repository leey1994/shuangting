import 'dart:convert';

/// MusicFree 插件协议的数据模型。
///
/// 全部保留插件原始 JSON（raw），因为 `getMediaSource` / `getLyric` 等接口
/// 需要把完整的歌曲对象回传给插件，丢掉未知字段（例如 `$`、`qualities`）
/// 会导致部分插件取不到音源。

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

String _str(dynamic v) => v == null ? '' : v.toString();
int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? 0;
}

class MusicItem {
  MusicItem(this.raw);

  factory MusicItem.fromJson(Map<String, dynamic> json) => MusicItem(_asMap(json));

  final Map<String, dynamic> raw;

  String get id {
    for (final key in const ['id', 'mid', 'musicId', 'songId', 'hash', 'copyrightId', 'contentId']) {
      final v = raw[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }
  String get platform => _str(raw['platform']);
  String get title => _str(raw['title']);
  String get artist => _str(raw['artist']);
  String get album => _str(raw['album']);
  String get artwork => _str(raw['artwork'] ?? raw['coverImg']);
  String get alias => _str(raw['alias']);
  int get duration => _int(raw['duration']);
  String? get url => raw['url']?.toString();
  String get key => '$platform|$id';

  String get durationText {
    final d = duration;
    if (d <= 0) return '--:--';
    final m = d ~/ 60;
    final s = d % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get displayArtist => artist.isEmpty ? '未知歌手' : artist;
  String get displayAlbum => album.isEmpty ? '未知专辑' : album;

  MusicItem withLocalPath(String path) =>
      MusicItem({...raw, r'$localPath': path, r'$local': true});

  String? get localPath => raw[r'$localPath']?.toString();

  Map<String, dynamic> toJson() => raw;

  MusicItem copyWith(Map<String, dynamic> fields) => MusicItem({...raw, ...fields});
}

class AlbumItem {
  AlbumItem(this.raw);
  factory AlbumItem.fromJson(Map<String, dynamic> json) => AlbumItem(_asMap(json));
  final Map<String, dynamic> raw;

  String get id {
    for (final key in const ['id', 'sid', 'albumId', 'listId', 'specialId']) {
      final v = raw[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }
  String get platform => _str(raw['platform']);
  String get title => _str(raw['title']);
  String get artist => _str(raw['artist']);
  String get artwork => _str(raw['artwork'] ?? raw['coverImg']);
  String get description => _str(raw['description']);
  String get date => _str(raw['date']);
  int get worksNum => _int(raw['worksNum']);
  String get key => 'album:$platform|$id';
  Map<String, dynamic> toJson() => raw;
}

class ArtistItem {
  ArtistItem(this.raw);
  factory ArtistItem.fromJson(Map<String, dynamic> json) => ArtistItem(_asMap(json));
  final Map<String, dynamic> raw;

  String get id {
    for (final key in const ['id', 'sid', 'mid', 'singerId', 'artistId', 'userId']) {
      final v = raw[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }
  String get platform => _str(raw['platform']);
  String get name => _str(raw['name'] ?? raw['title']);
  String get avatar => _str(raw['avatar']);
  String get description => _str(raw['description']);
  int get fans => _int(raw['fans']);
  int get worksNum => _int(raw['worksNum']);
  String get key => 'artist:$platform|$id';
  Map<String, dynamic> toJson() => raw;
}

class SheetItem {
  SheetItem(this.raw);
  factory SheetItem.fromJson(Map<String, dynamic> json) => SheetItem(_asMap(json));
  final Map<String, dynamic> raw;

  String get id {
    for (final key in const ['id', 'sid', 'listId', 'specialId', 'tagId']) {
      final v = raw[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }
  String get platform => _str(raw['platform']);
  String get title => _str(raw['title']);
  String get artist => _str(raw['artist']);
  String get artwork => _str(raw['artwork'] ?? raw['coverImg']);
  String get description => _str(raw['description']);
  int get worksNum => _int(raw['worksNum']);
  String get key => 'sheet:$platform|$id';
  Map<String, dynamic> toJson() => raw;
}

class LyricSource {
  LyricSource({this.raw, this.lrc});
  factory LyricSource.fromJson(Object? json) {
    if (json == null) return LyricSource();
    if (json is String) return LyricSource(raw: json);
    final map = _asMap(json);
    return LyricSource(
      raw: map['rawLrc']?.toString() ?? map['raw']?.toString(),
      lrc: map['lrc']?.toString(),
    );
  }

  final String? raw;
  final String? lrc;

  String get text => (raw?.isNotEmpty ?? false) ? raw! : (lrc ?? '');

  Map<String, dynamic> toJson() => {
        if (raw != null) 'rawLrc': raw,
        if (lrc != null) 'lrc': lrc,
      };
}

class UserVariable {
  UserVariable({required this.key, this.name, this.hint});
  factory UserVariable.fromJson(Map<String, dynamic> json, [Map<String, dynamic>? saved]) =>
      UserVariable(
        key: _str(json['key']),
        name: json['name']?.toString(),
        hint: json['hint']?.toString(),
      );

  final String key;
  final String? name;
  final String? hint;

  Map<String, dynamic> toJson() => {
        'key': key,
        if (name != null) 'name': name,
        if (hint != null) 'hint': hint,
      };
}

/// 本地维护的插件元信息（与 JS 文件分开存储）。
class PluginRecord {
  PluginRecord({
    required this.platform,
    this.version = '0.0.0',
    this.author = '',
    this.description = '',
    this.srcUrl = '',
    this.file = '',
    this.supportedSearchType = const [],
    this.primaryKey = const [],
    this.methods = const {},
    this.variables = const {},
    this.enabled = true,
    this.order = 0,
    this.installedAt = 0,
  });

  String platform;
  String version;
  String author;
  String description;
  String srcUrl;
  String file;
  List<String> supportedSearchType;
  List<String> primaryKey;
  Set<String> methods;
  Map<String, String> variables;
  bool enabled;
  int order;
  int installedAt;

  String get displayVersion => version.isEmpty ? '0.0.0' : version;

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'version': version,
        'author': author,
        'description': description,
        'srcUrl': srcUrl,
        'file': file,
        'supportedSearchType': supportedSearchType,
        'primaryKey': primaryKey,
        'methods': methods.toList(),
        'variables': variables,
        'enabled': enabled,
        'order': order,
        'installedAt': installedAt,
      };

  factory PluginRecord.fromJson(Map<String, dynamic> json) => PluginRecord(
        platform: _str(json['platform']),
        version: _str(json['version']),
        author: _str(json['author']),
        description: _str(json['description']),
        srcUrl: _str(json['srcUrl']),
        file: _str(json['file']),
        supportedSearchType: (json['supportedSearchType'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        primaryKey: (json['primaryKey'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        methods: ((json['methods'] as List?) ?? []).map((e) => e.toString()).toSet(),
        variables: (json['variables'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
        enabled: json['enabled'] != false,
        order: _int(json['order']),
        installedAt: _int(json['installedAt']),
      );
}

/// 本地歌单（我喜欢 / 用户歌单）。
class Playlist {
  Playlist({
    required this.id,
    required this.name,
    this.cover = '',
    this.description = '',
    List<MusicItem>? songs,
    this.createdAt = 0,
    this.updatedAt = 0,
  }) : songs = songs ?? [];

  String id;
  String name;
  String cover;
  String description;
  List<MusicItem> songs;
  int createdAt;
  int updatedAt;

  bool get isFavorites => id == favoritesId;
  static const favoritesId = 'local::favorites';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cover': cover,
        'description': description,
        'songs': songs.map((e) => e.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: _str(json['id']),
        name: _str(json['name']),
        cover: _str(json['cover']),
        description: _str(json['description']),
        songs: ((json['songs'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => MusicItem.fromJson(_asMap(e)))
            .toList(),
        createdAt: _int(json['createdAt']),
        updatedAt: _int(json['updatedAt']),
      );
}

class HistoryEntry {
  HistoryEntry({required this.song, required this.playedAt});
  final MusicItem song;
  final int playedAt;

  Map<String, dynamic> toJson() => {'song': song.toJson(), 'playedAt': playedAt};
  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        song: MusicItem.fromJson(_asMap(json['song'])),
        playedAt: _int(json['playedAt']),
      );
}

class MediaSourceInfo {
  MediaSourceInfo({
    this.url,
    this.headers = const {},
    this.quality,
    this.userAgent,
    this.statusCode,
    this.mimeType,
  });
  final String? url;
  final Map<String, String> headers;
  final String? quality;
  final String? userAgent;
  final int? statusCode;
  final String? mimeType;

  Map<String, dynamic> toJson() => {
        'url': url,
        'headers': headers,
        if (quality != null) 'quality': quality,
        if (userAgent != null) 'userAgent': userAgent,
        if (statusCode != null) 'statusCode': statusCode,
        if (mimeType != null) 'mimeType': mimeType,
      };

  factory MediaSourceInfo.fromJson(Map<String, dynamic> json) {
    final headers = _asMap(json['headers']).map((k, v) => MapEntry(k, v.toString()));
    final status = json['statusCode'] ?? json['status'];
    final mime = json['mimeType'] ?? json['type'] ?? headers['content-type'] ?? headers['Content-Type'];
    return MediaSourceInfo(
      url: json['url']?.toString(),
      headers: headers,
      quality: json['quality']?.toString(),
      userAgent: json['userAgent']?.toString(),
      statusCode: status == null ? null : _int(status),
      mimeType: mime?.toString(),
    );
  }
}

String encodeJson(Object? value) => jsonEncode(value);
