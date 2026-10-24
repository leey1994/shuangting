import 'package:shuangting/data/kg_api.dart';

Future<void> main() async {
  final api = KgApi();
  for (final q in ['晴天', '恋人', '无名的人']) {
    final songs = await api.searchSongs(q);
    if (songs.isEmpty) { print('$q: no song'); continue; }
    final s = songs.first;
    final doc = await api.lyrics(s);
    print('$q -> ${s.title} hash=${s.hash} dur=${s.duration} lines=${doc?.lines.length}');
    if (doc != null && doc.lines.isNotEmpty) print('   ${doc.lines.first.startMs} ${doc.lines.first.text}');
  }
}
