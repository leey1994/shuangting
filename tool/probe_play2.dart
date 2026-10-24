import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shuangting/data/kg_api.dart';

Future<void> main() async {
  final api = KgApi();
  final songs = await api.searchSongs('晴天');
  for (final s in songs.take(3)) {
    print('${s.title} | ${s.artist} | hash=${s.hash} | hashes=${s.hashes}');
    for (final q in ['320', '128']) {
      final h = s.hashFor(q);
      final key = md5.convert(utf8.encode('${h}kgcloudv2')).toString();
      final br = q == '128' ? '128' : '320';
      final url = 'https://trackercdn.kugou.com/i/v2/?key=$key&hash=$h&br=$br&appid=1005&pid=2&cmd=25&behavior=play';
      final r = await http.get(Uri.parse(url), headers: {'User-Agent': KgApi.userAgent});
      print('  $q -> ${r.statusCode} ${r.body.substring(0, r.body.length.clamp(0, 160))}');
    }
  }
}
