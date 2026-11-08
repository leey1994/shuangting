class LyricLine {
  LyricLine(this.time, this.text);
  final Duration time;
  final String text;
}

class LyricDoc {
  LyricDoc({required this.lines, this.title, this.artist, this.album});
  final List<LyricLine> lines;
  final String? title;
  final String? artist;
  final String? album;

  bool get synced => lines.any((e) => e.time > Duration.zero);
  bool get isEmpty => lines.isEmpty;
}

LyricDoc parseLyric(String? raw) {
  final lines = <LyricLine>[];
  String? title, artist, album;
  if (raw == null || raw.trim().isEmpty) {
    return LyricDoc(lines: lines);
  }
  final tagRe = RegExp(r'^\[(ti|ar|al):(.*)\]$', caseSensitive: false);
  final timeRe = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

  for (final rawLine in raw.split(RegExp(r'\r\n|\r|\n'))) {
    final line = rawLine.trimRight();
    if (line.isEmpty) continue;
    final tag = tagRe.firstMatch(line);
    if (tag != null) {
      final key = tag.group(1)!.toLowerCase();
      final value = tag.group(2)!.trim();
      if (key == 'ti') title = value;
      if (key == 'ar') artist = value;
      if (key == 'al') album = value;
      continue;
    }
    final matches = timeRe.allMatches(line);
    if (matches.isEmpty) {
      continue;
    }
    final textStart = matches.last.end;
    final text = line.substring(textStart).trim();
    for (final m in matches) {
      final minutes = int.tryParse(m.group(1)!) ?? 0;
      final seconds = int.tryParse(m.group(2)!) ?? 0;
      final fracRaw = m.group(3) ?? '';
      var millis = 0;
      if (fracRaw.length == 1) {
        millis = int.parse(fracRaw) * 100;
      } else if (fracRaw.length == 2) millis = int.parse(fracRaw) * 10;
      else if (fracRaw.length >= 3) millis = int.parse(fracRaw.substring(0, 3));
      lines.add(LyricLine(
        Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
        text,
      ));
    }
  }

  if (lines.isEmpty) {
    // 无时间戳：按纯文本展示
    for (final l in raw.split(RegExp(r'\r\n|\r|\n'))) {
      if (l.trim().isNotEmpty) lines.add(LyricLine(Duration.zero, l.trim()));
    }
  } else {
    lines.sort((a, b) => a.time.compareTo(b.time));
  }
  return LyricDoc(lines: lines, title: title, artist: artist, album: album);
}

int lyricIndexAt(List<LyricLine> lines, Duration position) {
  if (lines.isEmpty) return -1;
  var lo = 0, hi = lines.length - 1, ans = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (lines[mid].time <= position) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}
