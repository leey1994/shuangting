/// 应用元信息：版本、仓库、作者。
/// 版本运行时会用 package_info_plus 覆盖，避免与构建配置不一致。
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static const appName = '爽听';
  static const slogan = '纯粹地听歌';
  static const author = 'leey';
  static const email = 'leey1994@163.com';
  static const repoOwner = 'leey1994';
  static const repoName = 'shuangting';
  static const repoUrl = 'https://github.com/leey1994/shuangting';
  static const releasesUrl = '$repoUrl/releases';
  static const issuesUrl = '$repoUrl/issues';
  static const homepageUrl = 'https://leey1994.github.io/shuangting/';
  static const latestReleaseApi =
      'https://api.github.com/repos/leey1994/shuangting/releases/latest';

  /// 构建期默认值，运行时由 [load] 覆盖为真实版本。
  static String version = '1.1.0';
  static String buildNumber = '2002';

  static String get fullVersion => '$version+$buildNumber';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
      if (info.buildNumber.isNotEmpty) buildNumber = info.buildNumber;
    } catch (_) {}
  }
}
