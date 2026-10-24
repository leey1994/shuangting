import 'dart:convert';
import 'package:archive/archive.dart';
import '../data/models.dart';

const _krcKey = [
  0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47,
  0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69,
];

LyricDoc? parseKrc(String base64Content) {
  try {
    var data = base64Decode(base64Content.trim());
    if (data.length < 8) return null;
    if (String.fromCharCodes(data.take(4)) == 'krc1') {
      data = data.sublist(4);
    }
    for (var i = 0; i < data.length; i++) {
      data[i] ^= _krcKey[i % _krcKey.length];
    }
    final inflated = ZLibDecoder().decodeBytes(data);
    final text = utf8.decode(inflated, allowMalformed: true);
    return _parseKrcText(text);
  } catch (_) {
    return null;
  }
}

LyricDoc? _parseKrcText(String text) {
  final lines = <LyricLine>[];
  final lineReg = RegExp(r'^\[(\d+),(\d+)\](.*)$');
  final wordReg = RegExp(r'<(\d+),(\d+),\d+>([^<]*)');
  for (final raw in const LineSplitter().convert(text)) {
    final m = lineReg.firstMatch(raw.trim());
    if (m == null) continue;
    final start = int.tryParse(m.group(1)!) ?? 0;
    final duration = int.tryParse(m.group(2)!) ?? 0;
    final body = m.group(3) ?? '';
    final words = <LyricWord>[];
    for (final wm in wordReg.allMatches(body)) {
      final wStart = int.tryParse(wm.group(1)!) ?? 0;
      final wDur = int.tryParse(wm.group(2)!) ?? 0;
      final wText = wm.group(3) ?? '';
      if (wText.trim().isEmpty) continue;
      words.add(LyricWord(start + wStart, wDur, wText));
    }
    var plain = body.replaceAll(wordReg, '').trim();
    if (plain.isEmpty && words.isNotEmpty) {
      plain = words.map((e) => e.text).join().trim();
    }
    if (plain.isEmpty) continue;
    lines.add(LyricLine(
      startMs: start,
      durationMs: duration > 0 ? duration : 3000,
      text: plain,
      words: words,
    ));
  }
  if (lines.isEmpty) return null;
  lines.sort((a, b) => a.startMs.compareTo(b.startMs));
  return LyricDoc(lines: lines, karaoke: true);
}
