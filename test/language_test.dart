import 'package:flutter_test/flutter_test.dart';
import 'package:shuangting/core/settings.dart';
import 'package:shuangting/ui/widgets/common.dart';

void main() {
  test('切换英文后关键界面文本生效', () async {
    await AppPaths.init();
    await Settings.instance.load();
    await Settings.instance.set('language', 'en');
    expect(t('发现'), 'Discover');
    expect(t('音乐库'), 'Library');
    expect(t('聚合榜单'), 'Aggregated charts');
    await Settings.instance.set('language', 'zh');
    expect(t('发现'), '发现');
  });
}
