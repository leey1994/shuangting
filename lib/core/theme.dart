import 'package:flutter/material.dart';

import 'settings.dart';

class AppPalette {
  static const presets = <int>[
    0xFFFF6B5B, // 珊瑚
    0xFF4D8DFF, // 海蓝
    0xFF37C08A, // 森林
    0xFF8B5CF6, // 紫罗兰
    0xFFF5A524, // 琥珀
    0xFFFF5C8A, // 桃粉
  ];

  static const presetNames = ['珊瑚', '海蓝', '森林', '紫罗兰', '琥珀', '桃粉'];

  static Color seed(BuildContext context) {
    final value = Settings.instance.get<int>('themeSeed');
    return Color(value);
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF0E1116) : const Color(0xFFFAF7F2);

  static Color card(BuildContext context) =>
      isDark(context) ? const Color(0xFF191D24) : Colors.white;

  static Color muted(BuildContext context) =>
      isDark(context) ? const Color(0xFF9AA3B2) : const Color(0xFF6E7686);

  /// 从当前主题色派生的点缀色：同一套强调色下所有图标/卡片一起换色，
  /// 不再各处写死珊瑚/海蓝，避免换主题后部分界面「没跟着换」。
  static Color accent(BuildContext context, int step) {
    final hsl = HSLColor.fromColor(seed(context));
    return hsl
        .withHue((hsl.hue + step * 34) % 360)
        .withSaturation((hsl.saturation * 0.9).clamp(0.35, 1.0))
        .withLightness(isDark(context) ? 0.68 : 0.52)
        .toColor();
  }

  static LinearGradient brandGradient(BuildContext context) {
    final s = seed(context);
    final hsl = HSLColor.fromColor(s);
    final second = hsl
        .withHue((hsl.hue + 38) % 360)
        .withSaturation((hsl.saturation * 0.92).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0))
        .toColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [s, second],
    );
  }
}

class AppTheme {
  static ThemeData build(bool dark, Color seed) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      surface: dark ? const Color(0xFF0E1116) : const Color(0xFFFAF7F2),
      surfaceContainer: dark ? const Color(0xFF191D24) : Colors.white,
      surfaceContainerHigh: dark ? const Color(0xFF20252E) : const Color(0xFFF2EDE6),
      outlineVariant: dark ? const Color(0xFF2A303B) : const Color(0xFFE8E1D8),
    );

    // fromSeed 在部分色调上会挑出深色的 onPrimary，浅色模式下按钮文字发灰。
    // 直接按亮度决定前景色，保证主按钮对比度。
    final onPrimary = scheme.primary.computeLuminance() > 0.55 ? Colors.black : Colors.white;
    final tuned = scheme.copyWith(onPrimary: onPrimary, onPrimaryContainer: onPrimary);

    final textColor = dark ? const Color(0xFFF4F6FA) : const Color(0xFF191C22);
    final muted = dark ? const Color(0xFF9AA3B2) : const Color(0xFF6E7686);

    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: tuned,
      scaffoldBackgroundColor: tuned.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: textColor, displayColor: textColor)
        .copyWith(
          headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          bodySmall: base.textTheme.bodySmall?.copyWith(color: muted),
          labelSmall: base.textTheme.labelSmall?.copyWith(color: muted),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: textColor, fontSize: 20),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1B2028) : Colors.white,
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        backgroundColor: dark ? const Color(0xFF1B2028) : Colors.white,
        selectedColor: seed,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 0.7, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF262C36) : const Color(0xFF22262E),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: muted,
        textColor: textColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, color: muted)),
      ),
    );
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  void refresh() => notifyListeners();
}
