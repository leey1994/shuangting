import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/plugin/plugin_runtime.dart';

/// flutter_test 默认把所有 HTTP 拦截成 400；这里清掉覆盖，走真实网络，
/// 验证 QuickJS fetch/XHR 桥 → axios shim → 插件搜索 的完整链路。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  test('真实插件联网搜索', () async {
    final f = File('userdata/plugins/qq-source.plugin.v1.9.26.js');
    if (!f.existsSync()) return;
    final rt = await PluginRuntime.create(f.readAsStringSync());
    final res = await rt.call('search', ['周杰伦', 1, 'music'], timeout: const Duration(seconds: 60));
    rt.dispose();
    expect(res.ok, isTrue, reason: res.error);
    final data = (res.value as Map)['data'] as List? ?? const [];
    expect(data, isNotEmpty);
    expect((data.first as Map)['title'].toString(), isNotEmpty);
  }, skip: File('native/build/quickjs_c_bridge_plugin.dll').existsSync() ? false : '需要 native/build/quickjs_c_bridge_plugin.dll');
}