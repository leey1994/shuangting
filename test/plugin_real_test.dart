import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/plugin/plugin_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实混淆插件可加载（QQ 音乐源）', () async {
    final f = File('userdata/plugins/qq-source.plugin.v1.9.26.js');
    if (!f.existsSync()) return;
    final rt = await PluginRuntime.create(f.readAsStringSync());
    expect(rt.metadata.platform, 'qq');
    expect(rt.metadata.methods, contains('search'));
    expect(rt.metadata.methods, contains('getMediaSource'));
    rt.dispose();
  }, skip: File('native/build/quickjs_c_bridge_plugin.dll').existsSync() ? false : '需要 native/build/quickjs_c_bridge_plugin.dll（flutter build windows --debug 后复制）');
}
