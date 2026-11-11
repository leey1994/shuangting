import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/settings.dart';
import 'core/theme.dart';
import 'ui/shell.dart';
import 'ui/widgets/common.dart';

class ShuangTingApp extends StatelessWidget {
  const ShuangTingApp({super.key});

  ThemeMode _mode() {
    switch (Settings.instance.get<String>('themeMode')) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        Settings.instance,
        ThemeController.instance,
      ]),
      builder: (context, _) {
        final seed = Color(Settings.instance.get<int>('themeSeed'));
        final english = Settings.instance.isEnglish;
        return MaterialApp(
          // 语言切换时整树重建，保证所有页面（含已打开的弹层）立即换语言。
          key: ValueKey('app-${english ? 'en' : 'zh'}'),
          title: '爽听',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(false, seed),
          darkTheme: AppTheme.build(true, seed),
          themeMode: _mode(),
          locale: english ? const Locale('en') : const Locale('zh'),
          supportedLocales: const [Locale('zh'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppShell(),
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final style = brightness == Brightness.dark
                ? SystemUiOverlayStyle.light.copyWith(
                    systemNavigationBarColor: Colors.transparent,
                    systemStatusBarContrastEnforced: false,
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    systemNavigationBarColor: Colors.transparent,
                    systemStatusBarContrastEnforced: false,
                  );
            // 所有页面（含 push 出来的设置/主题等）都以主题背景打底：
            // 否则透明 Scaffold 会露出窗口默认白底，深色主题下变成白底白字。
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: style,
              child: AppBackground(child: child ?? const SizedBox.shrink()),
            );
          },
        );
      },
    );
  }
}
