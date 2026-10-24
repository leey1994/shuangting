import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// 酷狗登录加密套件（对齐参考项目 crypto.rs）：
/// ① AES-CBC+PKCS7，key/iv 按 md5(临时密钥串) 派生，输出 hex；
/// ② RSA 无填充（裸 modPow，左补 0 到 128 字节），大写 hex 的 pk；
/// ③ lite t1/t2 设备令牌（AES-128 + 固定 key/iv）。
class KgCrypto {
  static String md5Hex(String s) => md5.convert(utf8.encode(s)).toString();

  static String randomKey16() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static Uint8List _aesCbcPkcs7(
      List<int> key, List<int> iv, List<int> plain, bool enc) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()));
    cipher.init(
        enc,
        PaddedBlockCipherParameters(
            ParametersWithIV(KeyParameter(Uint8List.fromList(key)),
                Uint8List.fromList(iv)),
            null));
    final input = Uint8List.fromList(plain);
    if (enc) {
      // PaddedBlockCipherImpl 自行按 blockSize 补齐，无需手工 pad
      final out = cipher.process(input);
      return Uint8List.fromList(out);
    }
    return Uint8List.fromList(cipher.process(input));
  }

  /// JS cryptoAesEncrypt 语义：传 key/iv 直接用；不给则生成随机 16 位临时串，
  /// key = md5(临时串)（32 hex 字符按 utf8 即 32 字节 = AES-256），iv = key[16..32]。
  static ({String hex, String tempKey}) aesEncrypt(String data,
      {String key = '', String iv = ''}) {
    if (key.isEmpty) {
      final tk = randomKey16();
      final md = md5Hex(tk);
      key = md.substring(0, 32);
      iv = key.substring(16);
      final ct = _aesCbcPkcs7(key.codeUnits, iv.codeUnits, utf8.encode(data), true);
      return (hex: _hex(ct), tempKey: tk);
    }
    final ct = _aesCbcPkcs7(key.codeUnits, iv.codeUnits, utf8.encode(data), true);
    return (hex: _hex(ct), tempKey: '');
  }

  static String aesDecryptHex(String dataHex, String key,
      {String iv = ''}) {
    String realKey = key, realIv = iv;
    if (iv.isEmpty) {
      realKey = md5Hex(key).substring(0, 32);
      realIv = realKey.substring(16);
    }
    final pt = _aesCbcPkcs7(realKey.codeUnits, realIv.codeUnits, _unhex(dataHex), false);
    return utf8.decode(pt, allowMalformed: true);
  }

  static String liteT2(String data) =>
      aesEncrypt(data, key: 'fd14b35e3f81af3817a20ae7adae7020', iv: '17a20ae7adae7020').hex;

  static String liteT1(String data) =>
      aesEncrypt(data, key: '5e4ef500e9597fe004bd09a46d8add98', iv: '04bd09a46d8add98').hex;

  /// RSA 裸加密（JS cryptoRSAEncrypt：modPow 无填充，左补 0，输出大写 hex）。
  /// 模数取自酷狗 lite 公钥（RSA-1024，e=65537）。
  static String rsaLoginPk(String jsonStr) {
    final m = BigInt.parse(_liteModulus, radix: 16);
    final e = BigInt.parse('10001', radix: 16);
    final data = utf8.encode(jsonStr);
    if (data.length > 128) throw ArgumentError('RSA payload too long');
    final input = BigInt.parse(_hex(Uint8List.fromList(data)), radix: 16);
    final c = input.modPow(e, m);
    var hexStr = c.toRadixString(16);
    if (hexStr.length.isOdd) hexStr = '0$hexStr';
    final padded = hexStr.padLeft(256, '0'); // 128 bytes
    return padded.toUpperCase();
  }

  /// 手机号掩码（参考实现：首 2 位 + '*****' + 第 11 位，如 `13*****0`）。
  static String maskMobile(String mobile) {
    if (mobile.length < 3) return mobile;
    final last = mobile.length > 10 ? mobile[10] : '';
    return '${mobile.substring(0, 2)}*****$last';
  }

  static String _hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  static List<int> _unhex(String s) {
    final out = <int>[];
    for (var i = 0; i + 1 < s.length; i += 2) {
      out.add(int.parse(s.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  static const _liteModulus = 'C40A2D0DA76511F3BB1CC2BBD3AFBD8BEA83B4D6B05B6C13EB8920C53F1AF767'
      '9B32BA0D0EDB843240EF1B836EFED3EE240734C14C1399FD6594D16AF22F52525D14D72E0155C6DCC'
      '8638D4F7BB94F3A0B1F4C29F991972F2A160A25EB0A9E724336BE7F69BBD319FFAB1C6DD8470B021'
      'DC434F3FABA89F4A2A01B33BDBDD08B';
}
