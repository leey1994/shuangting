import 'package:shuangting/data/kg_api.dart';

Future<void> main() async {
  final api = KgApi();
  final songs = await api.rankSongs(6666, pageSize: 8);
  for (final s in songs) {
    final r = await api.resolveAudio(s, '320');
    print('${s.title} | ${s.artist} | vip=${s.vip} | ${r?.quality} ${r?.url.split('?').first ?? 'FAIL'}');
  }
}
