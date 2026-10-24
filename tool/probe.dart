import 'dart:io';
void main() {
  for (final p in [
    r'C:\Users\leey1\AppData\Roaming\com.kugou\probe.txt',
    r'C:\Users\leey1\AppData\Local\Temp\probe_dart.txt',
  ]) {
    try {
      final f = File(p);
      f.parent.createSync(recursive: true);
      f.writeAsStringSync('ok');
      print('OK $p');
    } catch (e) {
      print('FAIL $p -> $e');
    }
  }
}
