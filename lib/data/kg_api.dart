import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/lyric_parser.dart';
import 'kugou_crypto.dart';
import 'models.dart';

class KgQrSession {
  final String key;
  final Uint8List image;
  const KgQrSession(this.key, this.image);
}

/// 扫码登录轮询结果。status: 1=等待扫码 2=已扫码 4=登录成功 0/其他=已失效
class KgQrCheck {
  final int status;
  final String cookie;
  final String nickname;
  const KgQrCheck({required this.status, this.cookie = '', this.nickname = ''});
}

/// 验证码 / 密码登录的统一结果。
class KgLoginResult {
  final String cookie;
  final String nickname;
  final String vipToken;
  const KgLoginResult({required this.cookie, this.nickname = '', this.vipToken = ''});
}

/// tracker 查询结果：urls 为 CDN 候选列表（按序尝试），vipLocked 表示被 VIP 锁定。
class TrackerHit {
  final List<String> urls;
  final bool vipLocked;
  const TrackerHit({required this.urls, this.vipLocked = false});
}

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

  // ---------- 密码 / 短信验证码登录（对齐 login.js + login_cellphone.js） ----------

  static const _androidRoute = 'LnT6xpN3khm36zse0QzvmgTZ3waWdRSA';
  static const _androidUa = 'Android16-1070-11440-130-0-wifi';
  static const _loginUa = 'Android16-1070-11440-130-0-LOGIN-wifi';

  // 上游 JS 内嵌的固定设备令牌（参考项目原样量）
  static const _devT1 =
      '562a6f12a6e803453647d16a08f5f0c2ff7eee692cba2ab74cc4c8ab47fc467561a7c6b5'
      '86ce7dc46a63613b246737c03a1dc8f8d162d8ce1d2c71893d19f1d4b797685a4c6d3d8'
      '1341cbde65e488c4829a9b4d42ef2df470eb102979fa5adcdd9b4eecfea8b909ff7599a'
      'beb49867640f10c3c70fc444effca9d15db44a9a6c907731e2bb0f22cd9b35363801699'
      '95693e5f0e2424e3378097d3813186e3fe96bbe7023808a0981b4e2b6135a76faac';
  static const _devT2 =
      '31c4daf4cf480169ccea1cb7d4a209295865a9d2b788510301694db229b87807'
      '469ea0d41b4d4b9173c2151da7294aeebfc9738df154bbdf11a4e117bb5dff6'
      'a3af8ce5ce333e681c1f29a44038f27567d58992eb81283e080778ac77db140'
      '0fdf49b7cf7e26be2e5af4da7830cc3be4';

  /// Android 签名：md5(ROUTE + sorted("k=v" 无分隔) + bodyJson + ROUTE)
  String _androidSign(Map<String, dynamic> params, String bodyJson) {
    final keys = params.keys.toList()..sort();
    final joined = [
      for (final k in keys) '$k=${_sigCoerce(params[k])}',
    ].join('');
    return KgCrypto.md5Hex('$_androidRoute$joined$bodyJson$_androidRoute');
  }

  static String _sigCoerce(dynamic v) {
    if (v is String) return v;
    if (v is Map || v is List) return jsonEncode(v);
    return v.toString();
  }

  /// 登录系网关 POST：dfid/mid/uuid/appid/clientver/clienttime 默认参数
  /// + android 签名，JSON body 原样传输。
  Future<Map<String, dynamic>> _loginPost({
    required String url,
    required Map<String, dynamic> body,
    String? router,
    Map<String, String>? headers,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final p = <String, dynamic>{
      'dfid': dfid,
      'mid': mid,
      'uuid': '-',
      'appid': 3116,
      'clientver': 11440,
      'clienttime': now,
    };
    final bodyJson = jsonEncode(body);
    final query = <String, String>{
      for (final e in p.entries)
        e.key: e.value is String ? e.value as String : '${e.value}',
    };
    query['signature'] = _androidSign(p, bodyJson);
    final uri = Uri.parse(url).replace(queryParameters: query);
    final req = http.Request('POST', uri);
    req.headers['Content-Type'] = 'application/json';
    req.headers['User-Agent'] = headers?['User-Agent'] ?? _androidUa;
    if (router != null) req.headers['x-router'] = router;
    headers?.forEach((k, v) => req.headers[k] = v);
    req.body = bodyJson;
    http.Response res;
    try {
      final streamed =
          await _client.send(req).timeout(const Duration(seconds: 20));
      res =
          await http.Response.fromStream(streamed).timeout(const Duration(seconds: 20));
    } on SocketException {
      throw KgException('网络连接失败，请检查网络');
    } on TimeoutException {
      throw KgException('网络请求超时');
    }
    final text = utf8.decode(res.bodyBytes, allowMalformed: true);
    Map<String, dynamic> data;
    try {
      data = (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      throw KgException('登录服务返回异常 (${res.statusCode})');
    }
    final status = (data['status'] as num?)?.toInt() ?? 0;
    final code = data['error_code'] ?? data['errcode'] ?? data['error_code'] ?? data['error'] ?? '';
    final errmsg = data['errmsg']?.toString() ?? '';
    if (status != 1) {
      final info = (data['error'] is Map
              ? ((data['error'] as Map)['errmsg']?.toString() ?? '')
              : errmsg)
          .trim();
      final cid = (code is Map ? code['error_code'] : code)?.toString() ?? '';
      throw KgException(
          info.isEmpty ? '登录失败${cid.isEmpty ? '' : ' [$cid]'}' : '$info${cid.isEmpty ? '' : ' [$cid]'}');
    }
    return data;
  }

  ///
  /// secu_params = AES(tk) 加密的结果对象 → 解出 token/userid/vip_*，组装 Cookie。
  ///
  KgLoginResult _secuToResult(Map<String, dynamic> resp, String tk) {
    final data = (resp['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final raw = data['secu_params']?.toString() ?? '';
    var token = data['token']?.toString() ?? '';
    var userid = (data['userid'] as num?)?.toInt();
    var vipToken = data['vip_token']?.toString() ?? '';
    var vipType = data['vip_type']?.toString() ?? '0';
    var nickname = data['nickname']?.toString() ?? '';
    if (raw.isNotEmpty) {
      try {
        final dec = jsonDecode(KgCrypto.aesDecryptHex(raw, tk));
        if (dec is Map) {
          token = dec['token']?.toString() ?? token;
          if (dec['userid'] is num) userid = (dec['userid'] as num).toInt();
          vipToken = dec['vip_token']?.toString() ?? vipToken;
          final vt = dec['vip_type'];
          vipType = vt == null || (vt is num && vt == 0) ? vipType : '$vt';
        }
      } catch (_) {}
    }
    final parts = [
      if (token.isNotEmpty) 'token=$token',
      if (userid != null) 'userid=$userid',
      if (vipToken.isNotEmpty) 'vip_token=$vipToken',
      'vip_type=$vipType',
    ];
    return KgLoginResult(
        cookie: parts.join('; '), nickname: nickname, vipToken: vipToken);
  }

  /// 账号 + 密码登录（/v9/login_by_pwd）。
  Future<KgLoginResult> passwordLogin(String account, String password) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final enc = KgCrypto.aesEncrypt(
        jsonEncode({'pwd': password, 'code': '', 'clienttime_ms': now}));
    final pk = KgCrypto.rsaLoginPk(
        jsonEncode({'clienttime_ms': now, 'key': enc.tempKey}));
    final resp = await _loginPost(
      url: 'https://gateway.kugou.com/v9/login_by_pwd',
      router: 'login.user.kugou.com',
      body: {
        'plat': 1,
        'support_multi': 1,
        'clienttime_ms': now,
        't1': _devT1,
        't2': _devT2,
        't3': 'MCwwLDAsMCwwLDAsMCwwLDA=',
        'username': account,
        'params': enc.hex,
        'pk': pk,
      },
    );
    return _secuToResult(resp, enc.tempKey);
  }

  /// 20006 = 上游签名/风控拒绝。2026 年起酷狗登录接口加了 SSA 反爬
  /// （MakcRe/KuGouMusicApi #206/#217：密码与验证码登录在第三方客户端会被
  /// 上游判为 20006，需官方 App 原生验证），保留协议实现，UI 层给出引导。
  static bool isUpstreamRejected(KgException e) =>
      e.message.contains('[20006]');

  /// 发送短信验证码（/v8/send_mobile_code，businessid=5）。
  Future<void> sendSmsCode(String mobile) async {
    mobile = mobile.trim();
    if (mobile.length != 11) throw KgException('手机号格式不正确');
    final now = DateTime.now().millisecondsSinceEpoch;
    final enc = KgCrypto.aesEncrypt(jsonEncode({'mobile': mobile}));
    final pk = KgCrypto.rsaLoginPk(
        jsonEncode({'clienttime_ms': now, 'key': enc.tempKey}));
    await _loginPost(
      url: 'https://gateway.kugou.com/v8/send_mobile_code',
      router: 'login.user.kugou.com',
      headers: {'User-Agent': _loginUa},
      body: {
        'plat': '1',
        'businessid': 5,
        'clienttime_ms': now,
        'pk': pk,
        'mobile': KgCrypto.maskMobile(mobile),
        'params': enc.hex,
      },
    );
  }

  /// 短信验证码登录（/v7/login_by_verifycode）。
  Future<KgLoginResult> smsLogin(String mobile, String code) async {
    mobile = mobile.trim();
    code = code.trim();
    if (mobile.length != 11 || code.isEmpty) {
      throw KgException('请输入手机号与验证码');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final enc =
        KgCrypto.aesEncrypt(jsonEncode({'mobile': mobile, 'code': code}));
    final pk = KgCrypto.rsaLoginPk(
        jsonEncode({'clienttime_ms': now, 'key': enc.tempKey}));
    final key = KgCrypto.md5Hex('3116$_androidRoute' '11440$now');
    final t2 =
        KgCrypto.liteT2('$mid|0f607264fc6318a92b9e13c65db7cd3c|||$now');
    final t1 = KgCrypto.liteT1('|$now');
    final resp = await _loginPost(
      url: 'https://loginserviceretry.kugou.com/v7/login_by_verifycode',
      headers: {'User-Agent': _loginUa, 'support-calm': '1'},
      body: {
        'plat': 1,
        'support_multi': 1,
        't1': t1,
        't2': t2,
        'clienttime_ms': now,
        'mobile': KgCrypto.maskMobile(mobile),
        'key': key,
        'pk': pk,
        'params': enc.hex,
        'dfid': dfid,
        'dev': '',
        'gitversion': '5f0b7c4',
      },
    );
    final r = _secuToResult(resp, enc.tempKey);
    final d = (resp['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dataT1 = d['t1']?.toString() ?? '';
    if (dataT1.isNotEmpty && r.cookie.isNotEmpty) {
      // t1 一并写入会话（签到等账号接口的参考做法）
      return KgLoginResult(
          cookie: '${r.cookie}; t1=$dataT1',
          nickname: r.nickname,
          vipToken: r.vipToken);
    }
    return r;
  }

  // ---------- 酷狗扫码登录（对齐参考项目 qr_create / qr_check 链路） ----------


  static const _webSalt = 'NVPh5oo715z5DIWAeQlhMDsWXXQV4hwt';

  /// 网页签名：md5(盐 + sorted("k=v" 无分隔拼接) + 盐)
  static String _webSign(Map<String, String> params) {
    final joined =
        params.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
    return _md5('$_webSalt${joined.join('')}$_webSalt');
  }

  Uri _signedUri(String path, Map<String, String> params) {
    final q = Map<String, String>.of(params);
    q['signature'] = _webSign(params);
    return Uri.https('login-user.kugou.com', path, q);
  }

  /// 生成扫码登录二维码：返回轮询 key 与 PNG 图片（上游直接给 base64 图片）。
  Future<KgQrSession> qrCreate() async {
    final data = await _get(
        _signedUri('/v2/qrcode', {
          'dfid': dfid,
          'mid': mid,
          'uuid': '-',
          'appid': '3116',
          'clientver': '11440',
          'clienttime': '${DateTime.now().millisecondsSinceEpoch}',
          'type': '1',
          'plat': '4',
          'qrcode_txt':
              'https://h5.kugou.com/apps/loginQRCode/html/index.html?appid=3116&',
          'srcappid': '2919',
        }).toString(),
        ttl: Duration.zero);
    final d = data?['data'];
    final key = d is Map ? (d['qrcode']?.toString() ?? '') : '';
    var img = d is Map ? (d['qrcode_img']?.toString() ?? '') : '';
    var png = Uint8List(0);
    if (img.startsWith('data:image')) {
      try {
        png = base64Decode(img.split('base64,').last);
      } catch (_) {}
    }
    if (key.isEmpty) throw KgException('二维码生成失败，请刷新重试');
    return KgQrSession(key, png);
  }

  /// 轮询扫码结果：1=等待 2=已扫码 4=成功（data 带 token/userid/vip_token/vip_type）。
  Future<KgQrCheck> qrCheck(String key) async {
    final data = await _get(
        _signedUri('/v2/get_userinfo_qrcode', {
          'dfid': dfid,
          'mid': mid,
          'uuid': '-',
          'appid': '3116',
          'clientver': '11440',
          'clienttime': '${DateTime.now().millisecondsSinceEpoch}',
          'plat': '4',
          'srcappid': '2919',
          'qrcode': key,
        }).toString(),
        ttl: Duration.zero);
    final d = data is Map ? data['data'] : null;
    final dm = d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
    final st = (dm['status'] as num?)?.toInt() ??
        ((data?['status'] as num?)?.toInt() ?? 0);
    if (st != 4) return KgQrCheck(status: st);
    final token = dm['token']?.toString() ?? '';
    final userid = dm['userid']?.toString() ?? '';
    final vipToken = dm['vip_token']?.toString() ?? '';
    final vipType = dm['vip_type']?.toString() ?? '';
    final parts = [
      if (token.isNotEmpty) 'token=$token',
      if (userid.isNotEmpty) 'userid=$userid',
      if (vipToken.isNotEmpty) 'vip_token=$vipToken',
      if (vipType.isNotEmpty) 'vip_type=$vipType',
    ];
    return KgQrCheck(
      status: 4,
      cookie: parts.join('; '),
      nickname: dm['nickname']?.toString() ?? '',
    );
  }

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
  /// 失败抛出明确原因：VIP 锁定 / 网络失败 / 无音源，而非笼统的 null。
  Future<ResolvedAudio> resolveAudio(Song song, String preferredQuality) async {
    final chain = switch (preferredQuality) {
      'hires' => ['hires', 'flac', '320', '128'],
      'flac' => ['flac', '320', '128'],
      '320' => ['320', '128'],
      _ => ['128', '320'],
    };
    var locked = false;
    var netFail = false;
    for (final q in chain) {
      final hash = song.hashFor(q);
      if (hash.isEmpty) continue;
      final hit = await _trackerQuery(hash, q);
      if (hit == null) {
        netFail = true;
        continue;
      }
      if (hit.vipLocked) {
        locked = true;
        continue;
      }
      if (hit.urls.isEmpty) continue;
      return ResolvedAudio(urls: hit.urls, quality: q, hash: hash);
    }
    if (locked) throw KgException('VIP 专享歌曲，登录酷狗账号后可播放');
    if (netFail) throw KgException('网络连接失败，请检查网络');
    throw KgException('暂无可用音源，请稍后再试');
  }

  /// 查询 tracker：一次抖动紧跟重试；status=2 表示 VIP 锁定；
  /// 返回 null 表示网络层面失败（区分于 VIP 锁 / 无音源）。
  Future<TrackerHit?> _trackerQuery(String hash, String quality) async {
    final br = switch (quality) {
      'flac' || 'hires' => 'flac',
      '320' => '320',
      _ => '128',
    };
    final key = _md5('${hash}kgcloudv2');
    final url = 'https://trackercdn.kugou.com/i/v2/?key=$key&hash=$hash&br=$br'
        '&appid=1005&pid=2&cmd=25&behavior=play';
    Map<String, dynamic>? data;
    try {
      final d = await _get(url, ttl: const Duration(minutes: 8));
      if (d is Map) data = Map<String, dynamic>.from(d);
    } catch (_) {
      try {
        final d = await _get('$url&retry=1', ttl: Duration.zero);
        if (d is Map) data = Map<String, dynamic>.from(d);
      } catch (_) {
        return null;
      }
    }
    final status = (data?['status'] as num?)?.toInt() ?? 0;
    if (status == 2) return const TrackerHit(urls: [], vipLocked: true);
    final raw = data?['url'];
    final urls = (raw is List
            ? raw
            : raw is String && raw.isNotEmpty
                ? [raw]
                : const [])
        .map((e) => e.toString())
        .map((u) =>
            u.startsWith('http://') ? u.replaceFirst('http://', 'https://') : u)
        .where((u) => u.isNotEmpty)
        .toList();
    return TrackerHit(urls: urls);
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
  final List<String> urls;
  final String quality;
  final String hash;
  const ResolvedAudio(
      {required this.urls, required this.quality, required this.hash});
  String get url => urls.first;
}
