import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:kugou_music_api_dart/src/core/api_client.dart';
import 'package:kugou_music_api_dart/src/utils/config.dart';
import 'package:kugou_music_api_dart/src/utils/encrypt_util.dart';
import 'package:kugou_music_api_dart/src/utils/helper_util.dart';

class Login {
  static dynamic _decodeDioData(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }

  /// 发送手机验证码 (上一回合的接口)
  static Future<Map<String, dynamic>> sendMobileCode(
    String mobile, {
    String? mid,
  }) async {
    final String? resolvedMid =
        mid ?? ApiClient().currentCookies['KUGOU_API_MID'];
    final Map<String, String>? requestCookie =
        resolvedMid != null && resolvedMid.isNotEmpty
        ? {'mid': resolvedMid, 'KUGOU_API_MID': resolvedMid}
        : null;

    return ApiClient().createRequest(
      method: 'POST',
      baseURL: 'http://login.user.kugou.com',
      url: '/v7/send_mobile_code',
      data: {'businessid': 5, 'mobile': mobile, 'plat': 3},
      encryptType: EncryptType.android,
      cookie: requestCookie,
    );
  }

  /// 发送验证码 (JS: captcha_sent)
  static Future<Map<String, dynamic>> captchaSent(
    String mobile, {
    String? mid,
  }) {
    return sendMobileCode(mobile, mid: mid);
  }

  /// 手机验证码登录 (终极 Boss 接口)
  /// [mobile] 手机号码
  /// [code] 接收到的验证码
  /// [cookie] 设备信息，非常重要（需要包含 KUGOU_API_GUID, KUGOU_API_MAC 等）
  static Future<Map<String, dynamic>> loginByVerifyCode(
    String mobile,
    String code, {
    Map<String, String>? cookie,
  }) async {
    // 获取毫秒级时间戳
    final int dateTime = DateTime.now().millisecondsSinceEpoch;

    // AES 加密手机号和验证码，生成一个临时的动态 key
    final Map<String, String> encrypt = EncryptUtil.cryptoAesEncrypt({
      'mobile': mobile,
      'code': code,
    });

    // 手机号脱敏掩码 (例如 19982903369 -> 19*9)
    final String maskedMobile = mobile.length >= 11
        ? '${mobile.substring(0, 2)}*${mobile.substring(10, 11)}'
        : mobile;

    // 准备 dfid
    final String dfid = cookie?['dfid'] ?? EncryptUtil.randomString(24);

    dynamic t2 = 0;
    dynamic t1 = 0;

    // 概念版特殊的 AES 加密逻辑
    if (ApiClient().isLite) {
      final String guid = cookie?['KUGOU_API_GUID'] ?? '';
      final String mac = cookie?['KUGOU_API_MAC'] ?? '';
      final String dev = cookie?['KUGOU_API_DEV'] ?? '';

      t2 = EncryptUtil.cryptoAesEncrypt(
        '$guid|0f607264fc6318a92b9e13c65db7cd3c|$mac|$dev|$dateTime',
        key: 'fd14b35e3f81af3817a20ae7adae7020',
        iv: '17a20ae7adae7020',
      )['str'];

      t1 = EncryptUtil.cryptoAesEncrypt(
        '|$dateTime',
        key: '5e4ef500e9597fe004bd09a46d8add98',
        iv: '04bd09a46d8add98',
      )['str'];
    }

    // 组装请求 Payload，应用 RSA 和 MD5 签名
    final Map<String, dynamic> dataMap = {
      'plat': 1,
      'support_multi': 1,
      't1': t1,
      't2': t2,
      'clienttime_ms': dateTime,
      'mobile': maskedMobile,
      // HelperUtil 签名
      'key': HelperUtil.signParamsKey(dateTime, isLite: ApiClient().isLite),
      // RSA 加密核心验证信息
      'pk': EncryptUtil.cryptoRSAEncrypt({
        'clienttime_ms': dateTime,
        'key': encrypt['key'], // 将 AES 生成的随机 key 通过 RSA 传给服务器
      }, isLite: ApiClient().isLite).toUpperCase(),
      'params': encrypt['str'], // AES 加密后的手机号和验证码
    };

    if (cookie?['userid'] != null) dataMap['userid'] = cookie!['userid'];

    if (ApiClient().isLite) {
      dataMap['dfid'] = dfid;
      dataMap['dev'] = cookie?['KUGOU_API_DEV'];
      dataMap['gitversion'] = '5f0b7c4';
    } else {
      dataMap['t3'] = 'MCwwLDAsMCwwLDAsMCwwLDA=';
    }

    // 发起底层网络请求
    final response = await ApiClient().createRequest(
      baseURL: 'https://loginserviceretry.kugou.com',
      url: '/v7/login_by_verifycode',
      method: 'POST',
      data: dataMap,
      encryptType: EncryptType.android,
      headers: {
        'support-calm': '1',
        'User-Agent': 'Android16-1070-11440-130-0-LOGIN-wifi',
      },
      cookie: cookie,
    );

    // 核心后处理：解密服务器返回的真实 Token
    if (response['status'] == 200) {
      final body = response['body'];
      if (body != null && body['status'] == 1) {
        final data = body['data'];
        if (data != null) {
          // 服务器会用我们刚才上传的临时 key (encrypt['key'])，加密真正的 token 下发回来！
          if (data['secu_params'] != null) {
            final dynamic getToken = EncryptUtil.cryptoAesDecrypt(
              data['secu_params'],
              encrypt['key']!,
            );

            // 将解密后的真实信息合并回结果中
            if (getToken is Map) {
              data.addAll(getToken);
              // 将新获取的关键信息注入到 cookie 列表里，方便前端提取保存
              getToken.forEach(
                (k, v) => (response['cookie'] as List).add('$k=$v'),
              );
            } else {
              data['token'] = getToken;
            }
          }

          // 准备自动注入底层引擎的凭证字典
          final Map<String, String> newCredentials = {};
          final List<String> cookies = response['cookie'] as List<String>;

          // 提取极其核心的资产凭证（兼容向 List 插入以及塞进 Map）
          if (data['t1'] != null) {
            cookies.add('t1=${data['t1']}');
            newCredentials['t1'] = data['t1'].toString();
          }
          if (data['token'] != null) {
            cookies.add('token=${data['token']}');
            newCredentials['token'] = data['token'].toString();
          }
          if (data['userid'] != null) {
            cookies.add('userid=${data['userid']}');
            newCredentials['userid'] = data['userid'].toString();
          }
          if (data['vip_type'] != null) {
            cookies.add('vip_type=${data['vip_type']}');
            newCredentials['vip_type'] = data['vip_type'].toString();
          }
          if (data['vip_token'] != null &&
              data['vip_token'].toString().isNotEmpty) {
            cookies.add('vip_token=${data['vip_token']}');
            newCredentials['vip_token'] = data['vip_token'].toString();
          }

          // ⚡️ 灵魂注入：全自动更新到底层引擎并触发 UserService 落盘！
          if (newCredentials.isNotEmpty) {
            ApiClient().updateCookies(newCredentials);
            print('📱 手机号/密码登录成功！已成功解密并注入核心凭证：${newCredentials.keys.toList()}');
          }
        }
      }
    }

    return response;
  }

  /// 手机号 + 验证码登录 (JS: login_cellphone)
  static Future<Map<String, dynamic>> loginCellphone(
    String mobile,
    String code, {
    Map<String, String>? cookie,
  }) {
    return loginByVerifyCode(mobile, code, cookie: cookie);
  }

  /// 获取设备信息 (login_device.js)
  /// [token] 当前用户的 token
  /// [userid] 当前用户的 userid
  static Future<Map<String, dynamic>> loginDevice({
    required String token,
    required int userid,
    Map<String, String>? cookie,
  }) async {
    final int clienttimeMs = DateTime.now().millisecondsSinceEpoch;

    // AES 加密 token 生成动态 key 和加密串
    final Map<String, String> encrypt = EncryptUtil.cryptoAesEncrypt({
      'token': token,
    });

    final Map<String, dynamic> dataMap = {
      'plat': 1,
      'userid': userid,
      'clienttime_ms': clienttimeMs,
      // 依然是熟悉的 RSA 验证套路
      'pk': EncryptUtil.cryptoRSAEncrypt({
        'clienttime_ms': clienttimeMs,
        'key': encrypt['key'],
      }).toUpperCase(),
      'params': encrypt['str'],
    };

    return ApiClient().createRequest(
      baseURL: 'https://userinfoservice.kugou.com',
      url: '/v2/get_dev',
      encryptType: EncryptType.android,
      method: 'POST',
      data: dataMap,
      cookie: cookie,
    );
  }

  /// 开放平台登录 (微信登录 login_openplat.js)
  /// [code] 微信客户端授权后返回的 code
  static Future<Map<String, dynamic>> loginOpenPlat(
    String code, {
    Map<String, String>? cookie,
  }) async {
    // ----------------------------------------
    // Step 1: 拿 code 去微信服务器换取 access_token
    // ----------------------------------------
    final String wxAppid = ApiClient().isLite
        ? Config.wxLiteAppid
        : Config.wxAppid;
    final String wxSecret = ApiClient().isLite
        ? Config.wxLiteSecret
        : Config.wxSecret;

    try {
      final wxResponse = await Dio().post(
        'https://api.weixin.qq.com/sns/oauth2/access_token',
        queryParameters: {
          'secret': wxSecret,
          'appid': wxAppid,
          'code': code,
          'grant_type': 'authorization_code',
        },
      );

      final wxData = _decodeDioData(wxResponse.data);
      if (wxData == null ||
          wxData is! Map ||
          wxData['access_token'] == null ||
          wxData['openid'] == null) {
        return {
          'status': 502,
          'body': {'status': 0, 'msg': 'WeChat Token Fetch Failed: $wxData'},
        };
      }

      final String accessToken = wxData['access_token'];
      final String openid = wxData['openid'];

      // ----------------------------------------
      // Step 2: 组装酷狗登录请求
      // ----------------------------------------
      final int dateNow = DateTime.now().millisecondsSinceEpoch;
      final encrypt = EncryptUtil.cryptoAesEncrypt({
        'access_token': accessToken,
      });
      final pk = EncryptUtil.cryptoRSAEncrypt({
        'clienttime_ms': dateNow,
        'key': encrypt['key'],
      }).toUpperCase();

      dynamic t2 = 0;
      dynamic t1 = 0;

      if (ApiClient().isLite) {
        final String guid = cookie?['KUGOU_API_GUID'] ?? '';
        final String mac = cookie?['KUGOU_API_MAC'] ?? '';
        final String dev = cookie?['KUGOU_API_DEV'] ?? '';

        t2 = EncryptUtil.cryptoAesEncrypt(
          '$guid|0f607264fc6318a92b9e13c65db7cd3c|$mac|$dev|$dateNow',
          key: 'fd14b35e3f81af3817a20ae7adae7020',
          iv: '17a20ae7adae7020',
        )['str'];

        t1 = EncryptUtil.cryptoAesEncrypt(
          '|$dateNow',
          key: '5e4ef500e9597fe004bd09a46d8add98',
          iv: '04bd09a46d8add98',
        )['str'];
      }

      final Map<String, dynamic> dataMap = {
        'dev': cookie?['KUGOU_API_DEV'] ?? '',
        'force_login': 1,
        'partnerid': 36, //6 应该代表微信渠道
        'clienttime_ms': dateNow,
        't1': t1,
        't2': t2,
        't3': 'MCwwLDAsMCwwLDAsMCwwLDA=',
        'openid': openid,
        'params': encrypt['str'],
        'pk': pk,
      };

      final response = await ApiClient().createRequest(
        url: '/v6/login_by_openplat',
        method: 'POST',
        data: dataMap,
        cookie: cookie,
        encryptType: EncryptType.android,
        headers: {'x-router': 'login.user.kugou.com'},
      );

      // ----------------------------------------
      // Step 3: 解密服务器返回的 Token
      // ----------------------------------------
      if (response['status'] == 200) {
        final body = response['body'];
        if (body != null && body['status'] == 1) {
          final data = body['data'];
          if (data != null) {
            final List<String> cookies = response['cookie'] as List<String>;
            final Map<String, String> newCredentials = {};

            // 解密核心 secu_params
            if (data['secu_params'] != null) {
              final dynamic getToken = EncryptUtil.cryptoAesDecrypt(
                data['secu_params'],
                encrypt['key']!,
              );

              if (getToken is Map) {
                data.addAll(getToken);
                getToken.forEach((k, v) {
                  cookies.add('$k=$v');
                  newCredentials[k.toString()] = v.toString();
                });
              } else {
                data['token'] = getToken;
                cookies.add('token=$getToken');
                newCredentials['token'] = getToken.toString();
              }
            }

            // 提取极其核心的资产凭证（不管有没有 secu_params 都尝试提取）
            if (data['t1'] != null) {
              cookies.add('t1=${data['t1']}');
              newCredentials['t1'] = data['t1'].toString();
            }
            if (data['userid'] != null) {
              cookies.add('userid=${data['userid']}');
              newCredentials['userid'] = data['userid'].toString();
            }
            if (data['vip_type'] != null) {
              cookies.add('vip_type=${data['vip_type']}');
              newCredentials['vip_type'] = data['vip_type'].toString();
            }
            if (data['vip_token'] != null &&
                data['vip_token'].toString().isNotEmpty) {
              cookies.add('vip_token=${data['vip_token']}');
              newCredentials['vip_token'] = data['vip_token'].toString();
            }

            // ⚡️ 灵魂注入：全自动更新到底层引擎并触发 UserService 落盘！
            if (newCredentials.isNotEmpty) {
              ApiClient().updateCookies(newCredentials);
              print(
                '🌐 开放平台(微信/QQ)登录成功！已成功解密并注入核心凭证：${newCredentials.keys.toList()}',
              );
            }
          }
        }
      }

      return response;
    } catch (e) {
      return {
        'status': 502,
        'body': {'status': 0, 'msg': 'WeChat API Error: $e'},
      };
    }
  }

  /// 生成扫码登录信息 (login_qr_create.js)
  /// [key] 扫码登录的唯一标识 (由 login_qr_key 接口获取)
  /// 返回用于生成二维码的原始 URL，建议在 Flutter UI 中使用 qr_flutter 渲染
  static Map<String, dynamic> loginQrCreate(String key) {
    final String url =
        'https://h5.kugou.com/apps/loginQRCode/html/index.html?qrcode=$key';

    return {
      'status': 200,
      'body': {
        'status': 1,
        'data': {
          'url': url,
          // 方便理解，这里我们不生成 base64，直接把 url 传出去即可
          'qr_text': url,
        },
      },
    };
  }

  /// 检查扫码登录状态 (login_qr_check.js)
  /// [key] 扫码登录的唯一标识 qrcode
  /// 返回状态说明：0:二维码过期, 1:等待扫码, 2:待确认, 4:授权登录成功
  static Future<Map<String, dynamic>> loginQrCheck(
    String key, {
    Map<String, String>? cookie,
  }) async {
    final response = await ApiClient().createRequest(
      baseURL: 'https://login-user.kugou.com',
      url: '/v2/get_userinfo_qrcode',
      method: 'GET',
      params: {
        'plat': 4,
        'appid': Config.appid,
        'srcappid': Config.srcappid,
        'qrcode': key,
      },
      encryptType: EncryptType.web, // 注意：这个接口用的是 web 端的签名算法！
      cookie: cookie,
    );

    // 核心后处理：扫码成功后提取 Token
    if (response['status'] == 200) {
      final body = response['body'];

      // 当 status == 4 时，代表用户在手机端点击了“允许登录”
      if (body != null && body['data'] != null && body['data']['status'] == 4) {
        final data = body['data'];
        final List<String> cookies = response['cookie'] as List<String>;
        final Map<String, String> newCredentials = {};
        if (data['token'] != null) {
          cookies.add('token=${data['token']}');
          newCredentials['token'] = data['token'].toString();
        }
        if (data['userid'] != null) {
          cookies.add('userid=${data['userid']}');
          newCredentials['userid'] = data['userid'].toString();
        }
        if (newCredentials.isNotEmpty) {
          ApiClient().updateCookies(newCredentials);
          print('🔑 登录成功！已自动拦截 Token 并注入全局引擎。');
        }
      }
    }

    return response;
  }

  /// 获取扫码登录的 Key (login_qr_key.js)
  /// [type] 可选参数，传 'web' 或其他，影响 appid
  static Future<Map<String, dynamic>> loginQrKey({
    String? type,
    Map<String, String>? cookie,
  }) async {
    // 根据 type 决定用哪个 appid (JS 原文逻辑)
    final int targetAppid = type == 'web' ? 1014 : 1001;

    return ApiClient().createRequest(
      baseURL: 'https://login-user.kugou.com',
      url: '/v2/qrcode',
      method: 'GET',
      params: {
        'appid': targetAppid,
        'type': 1,
        'plat': 4,
        'qrcode_txt':
            'https://h5.kugou.com/apps/loginQRCode/html/index.html?appid=${Config.appid}&',
        'srcappid': Config.srcappid,
      },
      encryptType: EncryptType.web,
      cookie: cookie,
    );
  }

  /// 刷新登录 Token / 自动登录 (login_token.js)
  /// [token] 本地保存的旧 Token
  /// [userid] 用户 ID
  static Future<Map<String, dynamic>> loginToken({
    String? token,
    String? userid,
    Map<String, String>? cookie,
  }) async {
    final int dateNow = DateTime.now().millisecondsSinceEpoch;
    final int clientTime = dateNow ~/ 1000;

    // 固定的 AES 密钥
    const String key = '90b8382a1bb4ccdcf063102053fd75b8';
    const String iv = 'f063102053fd75b8';
    const String liteKey = 'c24f74ca2820225badc01946dba4fdf7';
    const String liteIv = 'adc01946dba4fdf7';

    // 修复：保留入参，为空时才从内存/Cookie读取，并提供默认值防空指针
    token ??= cookie?['token'] ?? ApiClient().currentCookies['token'] ?? '';
    userid ??= cookie?['userid'] ?? ApiClient().currentCookies['userid'] ?? '0';

    // 1. 加密现有的 token 和 clienttime 作为 p3 参数 (使用固定 Key)
    final Map<String, String> encrypt = EncryptUtil.cryptoAesEncrypt(
      {'clienttime': clientTime, 'token': token},
      key: ApiClient().isLite ? liteKey : key,
      iv: ApiClient().isLite ? liteIv : iv,
    );

    // 2. 极其巧妙的设计：生成一个空的 AES 加密，主要目的是白嫖它的随机 Key
    final Map<String, String> encryptParams = EncryptUtil.cryptoAesEncrypt({});

    // 3. 用 RSA 加密刚才生成的随机 Key
    final String pk = EncryptUtil.cryptoRSAEncrypt({
      'clienttime_ms': dateNow,
      'key': encryptParams['key'],
    }).toUpperCase();

    dynamic t2 = 0;
    dynamic t1 = 0;

    // 概念版特殊参数
    if (ApiClient().isLite) {
      final String guid = cookie?['KUGOU_API_GUID'] ?? '';
      final String mac = cookie?['KUGOU_API_MAC'] ?? '';
      final String dev = cookie?['KUGOU_API_DEV'] ?? '';
      final String t1Cookie = cookie?['t1'] ?? '';

      t2 = EncryptUtil.cryptoAesEncrypt(
        '$guid|0f607264fc6318a92b9e13c65db7cd3c|$mac|$dev|$dateNow',
        key: 'fd14b35e3f81af3817a20ae7adae7020',
        iv: '17a20ae7adae7020',
      )['str'];

      t1 = EncryptUtil.cryptoAesEncrypt(
        t1Cookie.isNotEmpty ? '$t1Cookie|$dateNow' : '|$dateNow',
        key: '5e4ef500e9597fe004bd09a46d8add98',
        iv: '04bd09a46d8add98',
      )['str'];
    }

    // 拼装 Payload
    final Map<String, dynamic> dataMap = {
      'dfid': cookie?['dfid'] ?? ApiClient().currentCookies['dfid'] ?? '-',
      'p3': encrypt['str'],
      'plat': 1,
      't1': t1,
      't2': t2,
      't3': 'MCwwLDAsMCwwLDAsMCwwLDA=',
      'pk': pk,
      'params': encryptParams['str'],
      'userid': userid,
      'clienttime_ms': dateNow,
    };

    if (ApiClient().isLite) {
      dataMap['dev'] =
          cookie?['KUGOU_API_DEV'] ??
          ApiClient().currentCookies['KUGOU_API_DEV'];
    }

    // 发起请求
    final response = await ApiClient().createRequest(
      baseURL: 'http://login.user.kugou.com',
      url: '/v5/login_by_token',
      method: 'POST',
      data: dataMap,
      cookie: cookie,
      encryptType: EncryptType.android,
    );

    // ----------------------------------------
    // 后处理：解密 secu_params 并自动注入
    // ----------------------------------------
    if (response['status'] == 200) {
      final body = response['body'];
      if (body != null && body['status'] == 1) {
        final data = body['data'];
        if (data != null) {
          final List<String> cookies = response['cookie'] as List<String>;
          final Map<String, String> newCredentials = {};

          // ⚡️ 修复点：必须使用 encryptParams['key'] 去解密！
          if (data['secu_params'] != null) {
            final dynamic getToken = EncryptUtil.cryptoAesDecrypt(
              data['secu_params'],
              encryptParams['key']!, // <--- 这里是关键！
            );

            if (getToken is Map) {
              data.addAll(getToken);
              getToken.forEach((k, v) {
                cookies.add('$k=$v');
                newCredentials[k.toString()] = v.toString();
              });
            } else {
              data['token'] = getToken;
              cookies.add('token=$getToken');
              newCredentials['token'] = getToken.toString();
            }
          }

          if (data['t1'] != null) {
            cookies.add('t1=${data['t1']}');
            newCredentials['t1'] = data['t1'].toString();
          }
          if (data['userid'] != null) {
            cookies.add('userid=${data['userid']}');
            newCredentials['userid'] = data['userid'].toString();
          }
          if (data['vip_type'] != null) {
            cookies.add('vip_type=${data['vip_type']}');
            newCredentials['vip_type'] = data['vip_type'].toString();
          }
          if (data['vip_token'] != null &&
              data['vip_token'].toString().isNotEmpty) {
            cookies.add('vip_token=${data['vip_token']}');
            newCredentials['vip_token'] = data['vip_token'].toString();
          }

          // ⚡️ 灵魂注入
          if (newCredentials.isNotEmpty) {
            ApiClient().updateCookies(newCredentials);
            print('🌐 刷新登录成功！已解密并注入核心凭证：${newCredentials.keys.toList()}');
          }
        }
      }
    }
    return response;
  }
  // static Future<Map<String, dynamic>> loginToken({
  //   String? token,
  //   String? userid,
  //   Map<String, String>? cookie,
  // }) async {
  //   final int dateNow = DateTime.now().millisecondsSinceEpoch;
  //   final int clientTime = dateNow ~/ 1000;

  //   // 固定的 AES 密钥
  //   const String key = '90b8382a1bb4ccdcf063102053fd75b8';
  //   const String iv = 'f063102053fd75b8';
  //   const String liteKey = 'c24f74ca2820225badc01946dba4fdf7';
  //   const String liteIv = 'adc01946dba4fdf7';
  //   // 从cookie中获取token和userid
  //   token = ApiClient().currentCookies['token'];
  //   userid = ApiClient().currentCookies['userid'];

  //   // 加密现有的 token 和 clienttime 作为 p3 参数
  //   final Map<String, String> encrypt = EncryptUtil.cryptoAesEncrypt(
  //     {'clienttime': clientTime, 'token': token},
  //     key: ApiClient().isLite ? liteKey : key,
  //     iv: ApiClient().isLite ? liteIv : iv,
  //   );

  //   // 极其巧妙的设计：生成一个空的 AES 加密，主要目的是白嫖它的随机 Key
  //   final Map<String, String> encryptParams = EncryptUtil.cryptoAesEncrypt({});

  //   // 用 RSA 加密刚才生成的随机 Key
  //   final String pk = EncryptUtil.cryptoRSAEncrypt({
  //     'clienttime_ms': dateNow,
  //     'key': encryptParams['key'],
  //   }).toUpperCase();

  //   dynamic t2 = 0;
  //   dynamic t1 = 0;

  //   // 概念版特殊参数
  //   if (ApiClient().isLite) {
  //     final String guid = cookie?['KUGOU_API_GUID'] ?? '';
  //     final String mac = cookie?['KUGOU_API_MAC'] ?? '';
  //     final String dev = cookie?['KUGOU_API_DEV'] ?? '';
  //     final String t1Cookie = cookie?['t1'] ?? '';

  //     t2 = EncryptUtil.cryptoAesEncrypt(
  //       '$guid|0f607264fc6318a92b9e13c65db7cd3c|$mac|$dev|$dateNow',
  //       key: 'fd14b35e3f81af3817a20ae7adae7020',
  //       iv: '17a20ae7adae7020',
  //     )['str'];

  //     t1 = EncryptUtil.cryptoAesEncrypt(
  //       t1Cookie.isNotEmpty ? '$t1Cookie|$dateNow' : '|$dateNow',
  //       key: '5e4ef500e9597fe004bd09a46d8add98',
  //       iv: '04bd09a46d8add98',
  //     )['str'];
  //   }

  //   // 拼装 Payload
  //   final Map<String, dynamic> dataMap = {
  //     'dfid': cookie?['dfid'] ?? '-',
  //     'p3': encrypt['str'], // 传入加密后的 token 串
  //     'plat': 1,
  //     't1': t1,
  //     't2': t2,
  //     't3': 'MCwwLDAsMCwwLDAsMCwwLDA=',
  //     'pk': pk,
  //     'params': encryptParams['str'],
  //     'userid': userid,
  //     'clienttime_ms': dateNow,
  //   };

  //   if (ApiClient().isLite) {
  //     dataMap['dev'] = cookie?['KUGOU_API_DEV'];
  //   }

  //   // 发起请求
  //   final response = await ApiClient().createRequest(
  //     baseURL: 'http://login.user.kugou.com',
  //     url: '/v5/login_by_token',
  //     method: 'POST',
  //     data: dataMap,
  //     cookie: cookie,
  //     encryptType: EncryptType.android,
  //   );

  //   if (response['status'] == 200) {
  //     final body = response['body'];
  //     if (body != null && body['status'] == 1) {
  //       final data = body['data'];
  //       if (data != null) {
  //         final List<String> cookies = response['cookie'] as List<String>;
  //         final Map<String, String> newCredentials = {};
  //         print(data);

  //         // 解密核心 secu_params
  //         if (data['secu_params'] != null) {
  //           final dynamic getToken = EncryptUtil.cryptoAesDecrypt(
  //             data['secu_params'],
  //             encrypt['key']!,
  //           );

  //           if (getToken is Map) {
  //             data.addAll(getToken);
  //             getToken.forEach((k, v) {
  //               cookies.add('$k=$v');
  //               newCredentials[k.toString()] = v.toString();
  //             });
  //           } else {
  //             data['token'] = getToken;
  //             cookies.add('token=$getToken');
  //             newCredentials['token'] = getToken.toString();
  //           }
  //         }

  //         if (data['t1'] != null) {
  //           cookies.add('t1=${data['t1']}');
  //           newCredentials['t1'] = data['t1'].toString();
  //         }
  //         if (data['userid'] != null) {
  //           cookies.add('userid=${data['userid']}');
  //           newCredentials['userid'] = data['userid'].toString();
  //         }
  //         if (data['vip_type'] != null) {
  //           cookies.add('vip_type=${data['vip_type']}');
  //           newCredentials['vip_type'] = data['vip_type'].toString();
  //         }
  //         if (data['vip_token'] != null &&
  //             data['vip_token'].toString().isNotEmpty) {
  //           cookies.add('vip_token=${data['vip_token']}');
  //           newCredentials['vip_token'] = data['vip_token'].toString();
  //         }

  //         // ⚡️ 灵魂注入：全自动更新到底层引擎并触发 UserService 落盘！
  //         if (newCredentials.isNotEmpty) {
  //           ApiClient().updateCookies(newCredentials);
  //           print('🌐 刷新登录成功！已成功解密并注入核心凭证：${newCredentials.keys.toList()}');
  //         }
  //       }
  //     }
  //   }
  //   return response;
  // }

  /// 生成微信扫码登录信息 (login_wx_create.js)
  static Future<Map<String, dynamic>> loginWxCreate() async {
    final String wxAppid = ApiClient().isLite
        ? Config.wxLiteAppid
        : Config.wxAppid;
    final String wxSecret = ApiClient().isLite
        ? Config.wxLiteSecret
        : Config.wxSecret;
    final dio = Dio();

    try {
      // 获取 WeChat Access Token
      final tokenResp = await dio.get(
        'https://api.weixin.qq.com/cgi-bin/token',
        queryParameters: {
          'appid': wxAppid,
          'secret': wxSecret,
          'grant_type': 'client_credential',
        },
      );

      final tokenData = _decodeDioData(tokenResp.data);
      final String? accessToken = tokenData is Map
          ? tokenData['access_token']?.toString()
          : null;
      if (accessToken == null) {
        return {
          'status': 502,
          'body': {'status': 0, 'msg': 'WeChat Token Fetch Failed: $tokenData'},
        };
      }

      // 获取 WeChat Ticket
      final ticketResp = await dio.get(
        'https://api.weixin.qq.com/cgi-bin/ticket/getticket',
        queryParameters: {'access_token': accessToken, 'type': 2},
      );

      final ticketData = _decodeDioData(ticketResp.data);
      if (ticketData is! Map || ticketData['errcode'] != 0) {
        return {
          'status': 502,
          'body': {
            'status': 0,
            'msg': 'WeChat Ticket Fetch Failed: $ticketData',
          },
        };
      }

      final String ticket = ticketData['ticket'];
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String noncestr = EncryptUtil.cryptoMd5(EncryptUtil.randomString());

      // 生成签名并请求二维码 uuid
      final String signaturePrams =
          'appid=$wxAppid&noncestr=$noncestr&sdk_ticket=$ticket&timestamp=$timestamp';
      final String signature = EncryptUtil.cryptoSha1(signaturePrams);

      final connectResp = await dio.get(
        'https://open.weixin.qq.com/connect/sdk/qrconnect',
        queryParameters: {
          'appid': wxAppid,
          'noncestr': noncestr,
          'timestamp': timestamp,
          'scope': 'snsapi_userinfo',
          'signature': signature,
        },
      );

      final connectData = _decodeDioData(connectResp.data);
      if (connectData is Map && connectData['errcode'] == 0) {
        final data = Map<String, dynamic>.from(connectData);
        // 拼接出给前端用的扫码确认链接
        if (data['qrcode'] is Map) {
          data['qrcode']['qrcodeurl'] =
              'https://open.weixin.qq.com/connect/confirm?uuid=${data['uuid']}';
        }
        return {'status': 200, 'body': data};
      } else {
        return {
          'status': 502,
          'body': {'status': 0, 'msg': connectData},
        };
      }
    } catch (e) {
      return {
        'status': 502,
        'body': {'status': 0, 'msg': e.toString()},
      };
    }
  }

  /// 检查微信扫码状态 (login_wx_check.js)
  /// [uuid] 由 loginWxCreate 接口返回的 uuid
  static Future<Map<String, dynamic>> loginWxCheck(String uuid) async {
    try {
      final resp = await Dio().get(
        'https://long.open.weixin.qq.com/connect/l/qrconnect',
        queryParameters: {'f': 'json', 'uuid': uuid},
      );

      return {'status': 200, 'body': resp.data};
    } catch (e) {
      return {
        'status': 502,
        'body': {'status': 0, 'msg': e.toString()},
      };
    }
  }

  /// 账号密码登录 (login.js)
  /// [username] 用户名或手机号
  /// [password] 密码（明文，底层会自动加密）
  static Future<Map<String, dynamic>> loginByPwd(
    String username,
    String password, {
    Map<String, String>? cookie,
  }) async {
    final int dateNow = DateTime.now().millisecondsSinceEpoch;

    // AES 加密密码
    final Map<String, String> encrypt = EncryptUtil.cryptoAesEncrypt({
      'pwd': password,
      'code': '',
      'clienttime_ms': dateNow,
    });

    // 组装写死的 Payload (保留了 JS 作者找出的可用长特征码)
    final Map<String, dynamic> dataMap = {
      'plat': 1,
      'support_multi': 1,
      'clienttime_ms': dateNow,
      't1':
          '562a6f12a6e803453647d16a08f5f0c2ff7eee692cba2ab74cc4c8ab47fc467561a7c6b586ce7dc46a63613b246737c03a1dc8f8d162d8ce1d2c71893d19f1d4b797685a4c6d3d81341cbde65e488c4829a9b4d42ef2df470eb102979fa5adcdd9b4eecfea8b909ff7599abeb49867640f10c3c70fc444effca9d15db44a9a6c907731e2bb0f22cd9b3536380169995693e5f0e2424e3378097d3813186e3fe96bbe7023808a0981b4e2b6135a76faac',
      't2':
          '31c4daf4cf480169ccea1cb7d4a209295865a9d2b788510301694db229b87807469ea0d41b4d4b9173c2151da7294aeebfc9738df154bbdf11a4e117bb5dff6a3af8ce5ce333e681c1f29a44038f27567d58992eb81283e080778ac77db1400fdf49b7cf7e26be2e5af4da7830cc3be4',
      't3': 'MCwwLDAsMCwwLDAsMCwwLDA=',
      'username': username,
      'params': encrypt['str'],
      'pk': EncryptUtil.cryptoRSAEncrypt({
        'clienttime_ms': dateNow,
        'key': encrypt['key'],
      }).toUpperCase(),
    };

    final response = await ApiClient().createRequest(
      url: '/v9/login_by_pwd',
      method: 'POST',
      data: dataMap,
      encryptType: EncryptType.android,
      cookie: cookie,
      headers: {'x-router': 'login.user.kugou.com'},
    );

    if (response['status'] == 200) {
      final body = response['body'];
      if (body != null && body['status'] == 1) {
        final data = body['data'];
        if (data != null) {
          final List<String> cookies = response['cookie'] as List<String>;
          final Map<String, String> newCredentials = {};

          // 解密核心 secu_params 提取真·Token
          if (data['secu_params'] != null) {
            final dynamic getToken = EncryptUtil.cryptoAesDecrypt(
              data['secu_params'],
              encrypt['key']!,
            );

            if (getToken is Map) {
              data.addAll(getToken);
              getToken.forEach((k, v) {
                cookies.add('$k=$v');
                newCredentials[k.toString()] = v.toString();
              });
            } else {
              data['token'] = getToken;
              cookies.add('token=$getToken');
              newCredentials['token'] = getToken.toString();
            }
          }

          if (data['userid'] != null) {
            cookies.add('userid=${data['userid']}');
            newCredentials['userid'] = data['userid'].toString();
          }
          if (data['vip_type'] != null) {
            cookies.add('vip_type=${data['vip_type']}');
            newCredentials['vip_type'] = data['vip_type'].toString();
          }
          if (data['vip_token'] != null &&
              data['vip_token'].toString().isNotEmpty) {
            cookies.add('vip_token=${data['vip_token']}');
            newCredentials['vip_token'] = data['vip_token'].toString();
          }

          if (newCredentials.isNotEmpty) {
            ApiClient().updateCookies(newCredentials);
            print('🔐 密码登录成功！已成功解密并注入核心凭证：${newCredentials.keys.toList()}');
          }
        }
      }
    }

    return response;
  }
}
