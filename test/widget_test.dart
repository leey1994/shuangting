import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/format.dart';
import 'package:shuangting/core/lyric_parser.dart';
import 'package:shuangting/data/models.dart';

void main() {
  test('格式化时长与容量', () {
    expect(formatDuration(0), '--:--');
    expect(formatDuration(65), '1:05');
    expect(formatCount(12345), '1.2万');
    expect(formatBytes(1536), '1.5 KB');
  });

  test('LRC 歌词解析与二分索引', () {
    final doc = LyricDoc.fromLrc('[00:01.00]第一句\n[00:03.50]第二句')!;
    expect(doc.lines.length, 2);
    expect(doc.lines[1].startMs, 3500);
    expect(doc.lines[1].text, '第二句');
  });

  test('无效 KRC 返回 null 而不是抛错', () {
    expect(parseKrc('not-a-valid-krc'), isNull);
  });
}
