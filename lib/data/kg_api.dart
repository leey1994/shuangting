import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/lyric_parser.dart';
import 'models.dart';

class KgException implements Exception {
  final String message;
  KgException(this.message);
  @override
  String toString() => message;
}

class KgApi {
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
  final http.Client _client = http.Client();
  final Map<String, dynamic> _memory = {};
  final Map<String, DateTime> _cacheTime = {};
  String mid;
  String dfid;
  String cookie;

  KgApi({this.mid = '', this.dfid = '', this.cookie = ''}) {
    if (mid.isEmpty) mid = _randomHex(32);
    if (dfid.isEmpty) dfid = _randomHex(32);
  }

  static String _randomHex(int len) {
    final r = Random.secure();
    final sb = StringBuffer();
    const chars = '0123456789abcdef';
    for (var i = 0; i < len; i++) {
      sb.write(chars[r.nextInt(16)]);
    }
    return sb.toString();
  }

  Map<String, String> get _headers => {
        'User-Agent': userAgent,
        'Accept': 'application/json, text/plain, */*',
        'Cookie': 'kg_mid=$mid; kg_dfid=$dfid; kg_dfid_collect=$dfid'
            '${cookie.trim().isEmpty ? '' : '; ${cookie.trim()}'}',
      };

  Future<dynamic> _get(String url, {Duration ttl = const Duration(minutes: 5)}) async {
    final cachedAt = _cacheTime[url];
    if (cachedAt != null && DateTime.now().difference(cachedAt) < ttl) {
      return _memory[url];
    }
    http.Response res;
    try {
      res = await _client
          .get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 18));
    } on SocketException {
      throw KgException('网络连接失败，请检查网络');
    } on TimeoutException {
      throw KgException('网络请求超时');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw KgException('服务返回异常 (${res.statusCode})');
    }
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    dynamic data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      throw KgException('数据解析失败');
    }
    _memory[url] = data;
    _cacheTime[url] = DateTime.now();
    return data;
  }

  static String _md5(String input) => md5.convert(utf8.encode(input)).toString();

  Future<List<Song>> searchSongs(String keyword, {int page = 1, int pageSize = 30}) async {
    if (keyword.trim().isEmpty) return [];
    final url = 'https://songsearch.kugou.com/song_search_v2'
        '?keyword=${Uri.encodeQueryComponent(keyword)}&page=$page&pagesize=$pageSize'
        '&platform=WebFilter&userid=0&clientver=2000&iscorrection=1'
        '&privilege_filter=0&filter=10&area_code=1';
    final data = await _get(url, ttl: const Duration(minutes: 2));
    final lists = data?['data']?['lists'];
    if (lists is! List) return [];
    return lists
        .whereType<Map>()
        .map((e) => Song.fromSearch(Map<String, dynamic>.from(e)))
        .where((e) => e.hash.isNotEmpty)
        .toList();
  }

  Future<List<Playlist>> searchPlaylists(String keyword, {int page = 1, int pageSize = 24}) async {
    if (keyword.trim().isEmpty) return [];
    final url = 'http://mobilecdn.kugou.com/api/v3/search/special'
        '?keyword=${Uri.encodeQueryComponent(keyword)}&page=$page&pagesize=$pageSize&showtype=1';
    final data = await _get(url, ttl: const Duration(minutes: 10));
    final info = data?['data']?['info'];
    if (info is! List) return [];
    return info
        .whereType<Map>()
        .map((e) => Playlist.fromSearch(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<RankInfo>> ranks() async {
    const url = 'http://mobilecdn.kugou.com/api/v3/rank/list'
        '?version=9108&plat=0&showtype=2&parentid=0&apiver=2&area_code=1&tagtype=0';
    final data = await _get(url, ttl: const Duration(hours: 6));
    final info = data?['data']?['info'];
    if (info is! List) return [];
    return info
        .whereType<Map>()
        .map((e) => RankInfo.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id > 0)
        .toList();
  }

  Future<List<Song>> rankSongs(int rankId, {int page = 1, int pageSize = 30}) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/rank/song'
        '?version=9108&plat=0&pagesize=$pageSize&rankid=$rankId&area_code=1'
        '&page=$page&with_res_tag=0';
    final data = await _get(url, ttl: const Duration(minutes: 10));
    final info = data?['data']?['info'];
    if (info is! List) return [];
    return info
        .whereType<Map>()
        .map((e) => Song.fromMobile(Map<String, dynamic>.from(e)))
        .where((e) => e.hash.isNotEmpty)
        .toList();
  }

  Future<ArtistInfo> artistInfo(int id) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/singer/info?singerid=$id';
    final data = await _get(url, ttl: const Duration(hours: 6));
    final info = data?['data'];
    if (info is! Map) throw KgException('歌手信息加载失败');
    return ArtistInfo.fromJson(Map<String, dynamic>.from(info));
  }

  Future<List<Song>> artistSongs(int id, {int page = 1, int pageSize = 30}) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/singer/song'
        '?singerid=$id&page=$page&pagesize=$pageSize&sort=1&version=9108'
        '&plat=0&area_code=1&with_res_tag=0';
    final data = await _get(url, ttl: const Duration(minutes: 10));
    final info = data?['data']?['info'];
    if (info is! List) return [];
    return info
        .whereType<Map>()
        .map((e) => Song.fromMobile(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AlbumInfo> albumInfo(int id) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/album/info?albumid=$id';
    final data = await _get(url, ttl: const Duration(hours: 6));
    final info = data?['data'];
    if (info is! Map) throw KgException('专辑信息加载失败');
    return AlbumInfo.fromJson(Map<String, dynamic>.from(info));
  }

  Future<List<Song>> albumSongs(int id, {int page = 1, int pageSize = 30}) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/album/song'
        '?albumid=$id&page=$page&pagesize=$pageSize&version=9108'
        '&plat=0&area_code=1&with_res_tag=0';
    final data = await _get(url, ttl: const Duration(minutes: 10));
    final info = data?['data']?['info'];
    if (info is! List) return [];
    return info
        .whereType<Map>()
        .map((e) => Song.fromMobile(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Playlist> playlistInfo(int id) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/special/info?specialid=$id';
    final data = await _get(url, ttl: const Duration(hours: 3));
    final info = data?['data'];
    if (info is! Map) throw KgException('歌单信息加载失败');
    final j = Map<String, dynamic>.from(info);
    return Playlist(
      id: id,
      name: (j['specialname'] ?? '歌单').toString(),
      cover: (j['imgurl'] ?? '').toString(),
      creator: (j['nickname'] ?? '').toString(),
      songCount: (j['songcount'] as num?)?.toInt() ?? 0,
      playCount: (j['playcount'] as num?)?.toInt() ?? 0,
      intro: (j['intro'] ?? '').toString(),
    );
  }

  Future<List<Song>> playlistSongs(int id, {int page = 1, int pageSize = 30}) async {
    final url = 'http://mobilecdn.kugou.com/api/v3/special/song'
        '?specialid=$id&page=$page&pagesize=$pageSize&version=9108'
        '&plat=0&area_code=1&with_res_tag=0';
    final data = await _get(url, ttl: const Duration(minutes: 10));
    final info = data?['data']?['info'];
    if (info is! List) return [];
    return info
        .whereType<Map>()
        .map((e) => Song.fromMobile(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Resolves a playable URL. Falls back down the quality ladder.
  Future<ResolvedAudio?> resolveAudio(Song song, String preferredQuality) async {
    final chain = switch (preferredQuality) {
      'hires' => ['hires', 'flac', '320', '128'],
      'flac' => ['flac', '320', '128'],
      '320' => ['320', '128'],
      _ => ['128', '320'],
    };
    for (final q in chain) {
      final hash = song.hashFor(q);
      if (hash.isEmpty) continue;
      final url = await _trackerUrl(hash, q);
      if (url != null) {
        return ResolvedAudio(url: url, quality: q, hash: hash);
      }
    }
    return null;
  }

  Future<String?> _trackerUrl(String hash, String quality) async {
    final br = switch (quality) {
      'flac' || 'hires' => 'flac',
      '320' => '320',
      _ => '128',
    };
    final key = _md5('${hash}kgcloudv2');
    final url = 'https://trackercdn.kugou.com/i/v2/?key=$key&hash=$hash&br=$br'
        '&appid=1005&pid=2&cmd=25&behavior=play';
    try {
      final data = await _get(url, ttl: const Duration(minutes: 8));
      final urls = data?['url'];
      if (urls is List && urls.isNotEmpty) {
        var u = urls.first.toString();
        if (u.startsWith('http://')) u = u.replaceFirst('http://', 'https://');
        return u;
      }
    } catch (_) {}
    return null;
  }

  Future<LyricDoc?> lyrics(Song song) async {
    final q = 'ver=1&man=yes&client=mobi&keyword=&duration=${song.duration}'
        '&hash=${song.hash}';
    try {
      final search = await _get('https://krcs.kugou.com/search?$q',
          ttl: const Duration(hours: 24));
      final candidates = search?['candidates'];
      if (candidates is! List || candidates.isEmpty) return null;
      final cand = Map<String, dynamic>.from(candidates.first as Map);
      final id = cand['id'];
      final accesskey = cand['accesskey'];
      if (id == null || accesskey == null) return null;
      final dl = await _get(
          'https://lyrics.kugou.com/download?ver=1&client=pc&id=$id'
          '&accesskey=$accesskey&fmt=krc&charset=utf8',
          ttl: const Duration(hours: 24));
      final content = dl?['content']?.toString() ?? '';
      if (content.isEmpty) return null;
      final krc = parseKrc(content);
      if (krc != null) return krc;
      final lrc = LyricDoc.fromLrc(content);
      return lrc;
    } catch (_) {
      return null;
    }
  }

  Future<List<CommentItem>> comments(Song song, {int page = 1}) async {
    final ext = '${song.hash}|music';
    final url = 'https://m.comment.kugou.com/index.php?r=commentsv2/getCommentWithLike'
        '&code=fc4be23b4e972707f36b8a828a73a7a9&p=$page&pagesize=20'
        '&extdata=${Uri.encodeComponent(ext)}&clientver=2000';
    try {
      final data = await _get(url, ttl: const Duration(minutes: 2));
      final list = data?['list'] ?? data?['data']?['list'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => CommentItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> dailySignIn() async {
    if (cookie.trim().isEmpty) return null;
    try {
      final data = await _get(
          'https://wwwapi.kugou.com/yy/index.php?r=signin/index&clientver=2000',
          ttl: Duration.zero);
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (_) {
      return null;
    }
  }
}

class ResolvedAudio {
  final String url;
  final String quality;
  final String hash;
  const ResolvedAudio({required this.url, required this.quality, required this.hash});
}
