import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/plugin/plugin_runtime.dart';

/// 端到端冒烟：QuickJS + prelude + CommonJS(ModuleSource) + crypto-js + cheerio + Promise。
///
/// flutter test 不自带 native 产物，需要先构建一次 Windows 应用并复制 DLL：
///   flutter build windows --debug
///   mkdir native/build
///   copy build\windows\x64\runner\Debug\quickjs_c_bridge_plugin.dll native\build\
/// 找不到 DLL 时自动跳过。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dll = File('native/build/quickjs_c_bridge_plugin.dll');

  test('插件运行时加载依赖并返回 Promise 结果', () async {
    const source = r'''
const CryptoJS = require("crypto-js");
const { load } = require("cheerio");
module.exports = {
  platform: "smoke-test",
  version: "1.0.0",
  supportedSearchType: ["music"],
  async search(q) {
    const $ = load('<div class="t">' + q + '</div>');
    return {
      isEnd: true,
      data: [{
        id: "1",
        platform: "smoke-test",
        title: "中文歌:" + $(".t").text() + ":" + CryptoJS.MD5("a").toString().slice(0, 6)
      }]
    };
  }
};
''';
    final rt = await PluginRuntime.create(source);
    expect(rt.metadata.platform, 'smoke-test');
    expect(rt.metadata.methods, contains('search'));

    final res = await rt.call('search', ['hi', 1, 'music']);
    rt.dispose();

    expect(res.ok, isTrue, reason: res.error);
    final data = (res.value as Map)['data'] as List;
    expect((data.first as Map)['title'], '中文歌:hi:0cc175');
  }, skip: dll.existsSync() ? false : '缺少 native/build/quickjs_c_bridge_plugin.dll');
}
