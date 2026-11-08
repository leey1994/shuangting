import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/plugin/plugin_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('插件元信息可在后台 isolate 解析', () async {
    final assets = <String, String>{};
    for (final path in [PluginRuntime.preludeAsset, ...PluginRuntime.moduleAssetPaths]) {
      try {
        assets[path] = await rootBundle.loadString(path);
      } catch (_) {}
    }
    const source = '''
module.exports = {
  platform: "isolate-test",
  version: "1.2.3",
  supportedSearchType: ["music"],
  async search() { return { isEnd: true, data: [] }; }
};
''';
    final meta = await Isolate.run(() => PluginRuntime.inspect(source, assets: assets));
    expect(meta['platform'], 'isolate-test');
    expect(meta['version'], '1.2.3');
    expect((meta['methods'] as List), contains('search'));
  }, skip: File('native/build/quickjs_c_bridge_plugin.dll').existsSync() ? false : '需要 native/build/quickjs_c_bridge_plugin.dll');
}