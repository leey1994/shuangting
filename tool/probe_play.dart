import 'package:shuangting/data/kg_api.dart';

Future<void> main() async {
  final api = KgApi();

  // 1) web 签名可复算（对拍此前 Python 探针成功值）
  // sign 复算由 qrCreate 实际调用覆盖（私有函数不可跨库打印）

  // 2) 二维码创建
  final qr = await api.qrCreate();
  print('qrCreate key=${qr.key} png=${qr.image.length}B');
  final chk = await api.qrCheck(qr.key);
  print('qrCheck status=${chk.status}');

  // 3) 播放地址语义
  final songs = await api.searchSongs('晴天');
  for (final s in songs.take(2)) {
    try {
      final r = await api.resolveAudio(s, '320');
      print('${s.title} -> ${r.quality} ${r.url.substring(0, 60)}');
    } on KgException catch (e) {
      print('${s.title} -> EXC: ${e.message}');
    }
  }
}
