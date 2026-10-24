import 'dart:convert';

String _s(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

int _i(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}

String _cover(dynamic raw) {
  var u = _s(raw);
  if (u.isEmpty) return '';
  u = u.replaceAll('{size}', '400');
  if (u.startsWith('http://')) u = u.replaceFirst('http://', 'https://');
  return u;
}

class Song {
  final String hash;
  final String title;
  final String artist;
  final String album;
  final int albumId;
  final int artistId;
  final int duration;
  final String cover;
  final Map<String, String> hashes;
  final int audioId;
  final bool vip;
  final String localPath;

  const Song({
    required this.hash,
    required this.title,
    required this.artist,
    this.album = '',
    this.albumId = 0,
    this.artistId = 0,
    this.duration = 0,
    this.cover = '',
    this.hashes = const {},
    this.audioId = 0,
    this.vip = false,
    this.localPath = '',
  });

  String get coverUrl => _cover(cover);

  String hashFor(String quality) {
    switch (quality) {
      case 'hires':
        return hashes['hires'] ?? hashes['flac'] ?? hashes['320'] ?? hash;
      case 'flac':
        return hashes['flac'] ?? hashes['320'] ?? hash;
      case '320':
        return hashes['320'] ?? hash;
      default:
        return hash;
    }
  }

  bool get hasLossless =>
      (hashes['flac'] ?? '').isNotEmpty || (hashes['hires'] ?? '').isNotEmpty;

  String get qualityTag {
    if ((hashes['hires'] ?? '').isNotEmpty) return 'Hi-Res';
    if ((hashes['flac'] ?? '').isNotEmpty) return '无损';
    if ((hashes['320'] ?? '').isNotEmpty) return '320K';
    return '';
  }

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    int? albumId,
    int? artistId,
    String? cover,
    int? duration,
  }) {
    return Song(
      hash: hash,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      duration: duration ?? this.duration,
      cover: cover ?? this.cover,
      hashes: hashes,
      audioId: audioId,
      vip: vip,
      localPath: localPath,
    );
  }

  factory Song.fromSearch(Map<String, dynamic> j) {
    final tp = (j['trans_param'] is Map) ? j['trans_param'] as Map : const {};
    final singers = j['Singers'];
    var artistId = _i(j['SingerId'] is List && (j['SingerId'] as List).isNotEmpty
        ? (j['SingerId'] as List).first
        : 0);
    if (artistId == 0 && singers is List && singers.isNotEmpty) {
      artistId = _i((singers.first as Map)['id']);
    }
    final hashes = <String, String>{
      '128': _s(j['FileHash']),
      '320': _s(j['HQFileHash']),
      'flac': _s(j['SQFileHash']),
      'hires': _s(j['ResFileHash']).isNotEmpty
          ? _s(j['ResFileHash'])
          : _s(j['SuperFileHash']),
    }..removeWhere((k, v) => v.isEmpty);
    return Song(
      hash: _s(j['FileHash']),
      title: _s(j['SongName'], '未知歌曲'),
      artist: _s(j['SingerName'], '未知歌手'),
      album: _s(j['AlbumName']),
      albumId: _i(j['AlbumID']),
      artistId: artistId,
      duration: _i(j['Duration']),
      cover: _s(tp['union_cover']).isNotEmpty
          ? _s(tp['union_cover'])
          : _s(j['Image']),
      hashes: hashes,
      audioId: _i(j['Audioid']),
      vip: _i(j['Privilege']) > 0,
    );
  }

  factory Song.fromMobile(Map<String, dynamic> j) {
    final tp = (j['trans_param'] is Map) ? j['trans_param'] as Map : const {};
    final authors = j['authors'];
    var artistId = 0;
    var artistName = _s(j['singername']);
    if (authors is List && authors.isNotEmpty) {
      artistId = _i((authors.first as Map)['author_id']);
      if (artistName.isEmpty) artistName = _s((authors.first as Map)['author_name']);
    }
    var title = _s(j['songname']);
    final filename = _s(j['filename']);
    if (title.isEmpty && filename.isNotEmpty) {
      final sep = filename.indexOf(' - ');
      if (sep > 0) {
        if (artistName.isEmpty) artistName = filename.substring(0, sep).trim();
        title = filename.substring(sep + 3).trim();
      } else {
        title = filename;
      }
    }
    final hashes = <String, String>{
      '128': _s(j['hash']),
      '320': _s(j['hash_high']).isNotEmpty ? _s(j['hash_high']) : _s(j['320hash']),
      'flac': _s(j['sqhash']),
      'hires': _s(j['hash_super']),
    }..removeWhere((k, v) => v.isEmpty);
    return Song(
      hash: _s(j['hash']),
      title: title.isEmpty ? '未知歌曲' : title,
      artist: artistName.isEmpty ? '未知歌手' : artistName,
      album: _s(j['album_name']),
      albumId: _i(j['album_id']),
      artistId: artistId,
      duration: _i(j['duration']),
      cover: _s(j['album_sizable_cover']).isNotEmpty
          ? _s(j['album_sizable_cover'])
          : _s(tp['union_cover']),
      hashes: hashes,
      audioId: _i(j['audio_id']),
      vip: _i(j['privilege']) > 0 || _i(j['pay_type']) > 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'title': title,
        'artist': artist,
        'album': album,
        'albumId': albumId,
        'artistId': artistId,
        'duration': duration,
        'cover': cover,
        'hashes': hashes,
        'audioId': audioId,
        'vip': vip,
        'localPath': localPath,
      };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        hash: _s(j['hash']),
        title: _s(j['title'], '未知歌曲'),
        artist: _s(j['artist'], '未知歌手'),
        album: _s(j['album']),
        albumId: _i(j['albumId']),
        artistId: _i(j['artistId']),
        duration: _i(j['duration']),
        cover: _s(j['cover']),
        hashes: (j['hashes'] is Map)
            ? (j['hashes'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
            : const {},
        audioId: _i(j['audioId']),
        vip: j['vip'] == true,
        localPath: _s(j['localPath']),
      );

  @override
  bool operator ==(Object other) => other is Song && other.hash == hash;

  @override
  int get hashCode => hash.hashCode;
}


String _searchPlaylistCover(Map<String, dynamic> j) {
  final direct = _s(j['imgurl']);
  if (direct.isNotEmpty) return direct;
  final tp = j['trans_param'];
  if (tp is Map) {
    final skin = tp['skin'];
    if (skin is Map) {
      final thumb = _s(skin['thumbnail']);
      if (thumb.isNotEmpty) return thumb;
      final bg = skin['background_info'];
      if (bg is Map) {
        final img = bg['image_info'];
        if (img is Map) {
          final u = _s(img['image_url']);
          if (u.isNotEmpty) return u;
        }
      }
    }
  }
  return '';
}

class Playlist {
  final int id;
  final String name;
  final String cover;
  final String creator;
  final int songCount;
  final int playCount;
  final String intro;

  const Playlist({
    required this.id,
    required this.name,
    this.cover = '',
    this.creator = '',
    this.songCount = 0,
    this.playCount = 0,
    this.intro = '',
  });

  String get coverUrl => _cover(cover);

  factory Playlist.fromSearch(Map<String, dynamic> j) => Playlist(
        id: _i(j['specialid']),
        name: _s(j['specialname'], '未命名歌单'),
        cover: _searchPlaylistCover(j),
        creator: _s(j['nickname']),
        songCount: _i(j['songcount']),
        playCount: _i(j['playcount']),
        intro: _s(j['intro']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cover': cover,
        'creator': creator,
        'songCount': songCount,
        'playCount': playCount,
        'intro': intro,
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: _i(j['id']),
        name: _s(j['name'], '未命名歌单'),
        cover: _s(j['cover']),
        creator: _s(j['creator']),
        songCount: _i(j['songCount']),
        playCount: _i(j['playCount']),
        intro: _s(j['intro']),
      );
}

class RankInfo {
  final int id;
  final String name;
  final String cover;
  final String updateFrequency;
  final int playCount;

  const RankInfo({
    required this.id,
    required this.name,
    this.cover = '',
    this.updateFrequency = '',
    this.playCount = 0,
  });

  String get coverUrl => _cover(cover);

  factory RankInfo.fromJson(Map<String, dynamic> j) => RankInfo(
        id: _i(j['rankid']),
        name: _s(j['rankname'], '榜单'),
        cover: _s(j['img_cover']).isNotEmpty ? _s(j['img_cover']) : _s(j['img_9']),
        updateFrequency: _s(j['update_frequency']),
        playCount: _i(j['play_times']),
      );
}

class ArtistInfo {
  final int id;
  final String name;
  final String avatar;
  final int songCount;
  final String intro;

  const ArtistInfo({
    required this.id,
    required this.name,
    this.avatar = '',
    this.songCount = 0,
    this.intro = '',
  });

  String get avatarUrl => _cover(avatar);

  factory ArtistInfo.fromJson(Map<String, dynamic> j) => ArtistInfo(
        id: _i(j['singerid']),
        name: _s(j['singername'], '歌手'),
        avatar: _s(j['sizable_avatar']).isNotEmpty
            ? _s(j['sizable_avatar'])
            : _s(j['imgurl']),
        songCount: _i(j['songcount']),
        intro: _s(j['profile']).isNotEmpty ? _s(j['profile']) : _s(j['intro']),
      );
}

class AlbumInfo {
  final int id;
  final String name;
  final String cover;
  final String artist;
  final int songCount;
  final String publishTime;
  final String intro;

  const AlbumInfo({
    required this.id,
    required this.name,
    this.cover = '',
    this.artist = '',
    this.songCount = 0,
    this.publishTime = '',
    this.intro = '',
  });

  String get coverUrl => _cover(cover);

  factory AlbumInfo.fromJson(Map<String, dynamic> j) => AlbumInfo(
        id: _i(j['albumid']),
        name: _s(j['albumname'], '专辑'),
        cover: _s(j['img']),
        artist: _s(j['singername']),
        songCount: _i(j['songcount']),
        publishTime: _s(j['publishtime']),
        intro: _s(j['intro']),
      );
}

class CommentItem {
  final String user;
  final String avatar;
  final String content;
  final String time;
  final int likes;

  const CommentItem({
    required this.user,
    this.avatar = '',
    required this.content,
    this.time = '',
    this.likes = 0,
  });

  String get avatarUrl => _cover(avatar);

  factory CommentItem.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map : const {};
    return CommentItem(
      user: _s(user['nickname'], _s(j['nickname'], '听友')),
      avatar: _s(user['pic'], _s(user['avatar'], _s(j['user_pic']))),
      content: _s(j['content'], _s(j['comment'], '')),
      time: _s(j['addtime'], _s(j['time'])),
      likes: _i(j['like'], _i(j['likes'])),
    );
  }
}

class LyricWord {
  final int startMs;
  final int durationMs;
  final String text;
  const LyricWord(this.startMs, this.durationMs, this.text);
}

class LyricLine {
  final int startMs;
  final int durationMs;
  final String text;
  final List<LyricWord> words;
  const LyricLine({
    required this.startMs,
    required this.durationMs,
    required this.text,
    this.words = const [],
  });

  bool get hasWords => words.isNotEmpty;
}

class LyricDoc {
  final List<LyricLine> lines;
  final bool karaoke;
  const LyricDoc({required this.lines, this.karaoke = false});

  static LyricDoc? fromLrc(String raw) {
    final lines = <LyricLine>[];
    final reg = RegExp(r'\[(\d+):(\d+)(?:[.:](\d+))?\](.*)');
    for (final row in const LineSplitter().convert(raw)) {
      final m = reg.firstMatch(row);
      if (m == null) continue;
      final min = int.tryParse(m.group(1)!) ?? 0;
      final sec = int.tryParse(m.group(2)!) ?? 0;
      final fracRaw = m.group(3) ?? '0';
      final frac = int.tryParse(fracRaw.padRight(3, '0').substring(0, 3)) ?? 0;
      final text = m.group(4)!.trim();
      if (text.isEmpty) continue;
      lines.add(LyricLine(startMs: min * 60000 + sec * 1000 + frac, durationMs: 0, text: text));
    }
    if (lines.isEmpty) return null;
    lines.sort((a, b) => a.startMs.compareTo(b.startMs));
    final fixed = <LyricLine>[];
    for (var i = 0; i < lines.length; i++) {
      final next = i + 1 < lines.length ? lines[i + 1].startMs : lines[i].startMs + 5000;
      fixed.add(LyricLine(
        startMs: lines[i].startMs,
        durationMs: (next - lines[i].startMs).clamp(800, 12000),
        text: lines[i].text,
      ));
    }
    return LyricDoc(lines: fixed);
  }
}
