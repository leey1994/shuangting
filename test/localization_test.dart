import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuangting/core/settings.dart';

/// 中文 locale 下 showDialog 必须能找到 MaterialLocalizations。
void main() {
  testWidgets('中文环境可打开对话框', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('测试')),
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('测试'), findsOneWidget);
  });

  test('英文翻译覆盖整句与数量单位', () async {
    await Settings.instance.set('language', 'en');
    expect(L10n.instance.t('设置'), 'Settings');
    expect(L10n.instance.t('已收藏 3 首 · 戴上耳机，世界安静'), contains('3 songs'));
    expect(L10n.instance.t('6 个已安装'), '6 installed');
    await Settings.instance.set('language', 'zh');
    expect(L10n.instance.t('设置'), '设置');
  });
}
