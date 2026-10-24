import 'package:flutter/material.dart';

import '../data/store.dart';

class AppTheme {
  static const ink = Color(0xFF0A0C12);
  static const surface = Color(0xFF141925);
  static const surfaceHigh = Color(0xFF1D2433);
  static const cream = Color(0xFFF6F1E9);
  static const muted = Color(0xFF8E97A8);
  static const mint = Color(0xFF7CE7C4);

  static ThemeMode modeOf(SettingsModel s) {
    switch (s.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  }

  static bool isOled(SettingsModel s) => s.themeMode == 'black';

  static ThemeData build(SettingsModel s, Brightness platformBrightness) {
    final isDark = s.themeMode == 'dark' ||
        s.themeMode == 'black' ||
        (s.themeMode == 'system' && platformBrightness == Brightness.dark);
    final accent = s.accentColor;
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    final bg = isDark ? (isOled(s) ? Colors.black : ink) : cream;
    final card = isDark ? (isOled(s) ? const Color(0xFF080808) : surface) : Colors.white;
    final high = isDark ? (isOled(s) ? const Color(0xFF101010) : surfaceHigh) : const Color(0xFFF0E9DE);
    final scheme = base.copyWith(
      primary: accent,
      secondary: isDark ? mint : const Color(0xFF0F9D76),
      surface: card,
      surfaceContainerHighest: high,
      surfaceContainer: isDark ? (isOled(s) ? const Color(0xFF060606) : const Color(0xFF10141D)) : const Color(0xFFFBF7F1),
      onSurface: isDark ? const Color(0xFFF3F5F9) : const Color(0xFF16181D),
      outline: isDark ? const Color(0xFF2A3140) : const Color(0xFFDCD2C4),
    );

    final text = Typography.material2021(platform: TargetPlatform.android).white.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC', 'Noto Sans SC'],
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.5),
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.35), thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: high,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: high,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.45)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(100),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: accent,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.12),
        thumbColor: Colors.white,
        overlayColor: accent.withValues(alpha: 0.15),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF161C28) : Colors.white,
        modalBackgroundColor: isDark ? const Color(0xFF161C28) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.onSurface.withValues(alpha: 0.2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF171D29) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF262F40) : const Color(0xFF23262D),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: accent.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        height: 70,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : scheme.onSurface.withValues(alpha: 0.6)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accent : high),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }

  static List<Color> coverGradient(int seed, {bool isDark = true}) {
    final palettes = [
      [const Color(0xFFFF4D6D), const Color(0xFF7B5CFF)],
      [const Color(0xFF7CE7C4), const Color(0xFF1D6FFF)],
      [const Color(0xFFFFB347), const Color(0xFFFF4D6D)],
      [const Color(0xFF8B6CFF), const Color(0xFF00C2FF)],
      [const Color(0xFFF25C9C), const Color(0xFF8B6CFF)],
      [const Color(0xFF35D6A4), const Color(0xFFB6E338)],
    ];
    final p = palettes[seed.abs() % palettes.length];
    if (isDark) return p;
    return p.map((c) => Color.lerp(c, Colors.white, 0.35)!).toList();
  }
}
