import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/app_info.dart';
import 'package:shuangting/core/updater.dart';

/// 需要网络：校验对 GitHub Releases 的版本检查。
void main() {
  test('能从 GitHub Releases 检测到新版本', () async {
    AppInfo.version = '1.0.0';
    final info = await Updater.check(force: true);
    expect(info, isNotNull);
    expect(info!.version, '1.1.0');
    expect(info.pageUrl, contains('/releases/tag/'));
  }, timeout: const Timeout(Duration(seconds: 30)));
}
