String formatDuration(int seconds) {
  if (seconds <= 0) return '--:--';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatMs(int ms) {
  if (ms <= 0) return '0:00';
  return formatDuration(ms ~/ 1000);
}

String formatCount(int count) {
  if (count >= 100000000) return '${(count / 100000000).toStringAsFixed(1)}亿';
  if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
  return count.toString();
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

String qualityName(String q) => switch (q) {
      'hires' => 'Hi-Res',
      'flac' => '无损',
      '320' => '320K',
      '128' => '标准',
      _ => q.isEmpty ? '缓存' : q,
    };

String shortDate(int millis) {
  if (millis <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
}
