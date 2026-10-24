import 'dart:io';
void main() {
  final d = Directory(r'C:\Users\leey1\AppData\Local\Temp\opencode\sttmp');
  print('exists=${d.existsSync()}');
  try {
    final t = d.createTempSync('probe');
    print('temp ok ${t.path}');
    t.deleteSync(recursive: true);
  } catch (e) { print('temp fail $e'); }
  try {
    final f = File(r'\?\C:\Users\leey1\AppData\Local\Temp\opencode\sttmp\com.alexmercerind.media_kit.NativeReferenceHolder.test');
    f.createSync();
    print('file ok');
    f.deleteSync();
  } catch (e) { print('file fail $e'); }
}
