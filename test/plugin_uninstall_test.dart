import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/plugin/plugin_manager.dart';
import 'package:shuangting/core/plugin/plugin_runtime.dart';
import 'package:shuangting/core/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('安装后可删除插件', () async {
    await AppPaths.init();
    await Settings.instance.load();
    await PrefStore.instance.ensure();
    await PluginManager.instance.load();

    final record = await PluginManager.instance.installSource('''
module.exports = {
  platform: "delete-test",
  version: "1.0.0",
  supportedSearchType: ["music"]
};
''');
    expect(PluginManager.instance.byPlatform('delete-test'), isNotNull);

    await PluginManager.instance.uninstall(record);
    expect(PluginManager.instance.byPlatform('delete-test'), isNull);
    expect(pluginFile(record.file).existsSync(), isFalse);
  }, skip: File('native/build/quickjs_c_bridge_plugin.dll').existsSync() ? false : '需要 quickjs 原生 DLL');
}
