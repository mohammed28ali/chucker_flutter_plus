import 'package:flutter/material.dart';

import 'inspector_colors.dart';

abstract final class InspectorTheme {
  static const String package = 'chucker_flutter_plus';
  static const String fontRoboto = 'packages/$package/Roboto';
  static const String fontMonospace = 'packages/$package/monospace';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseSurface = isDark
        ? InspectorColors.surfaceDark
        : InspectorColors.surface;
    final scheme = ColorScheme.fromSeed(
      seedColor: InspectorColors.seed,
      brightness: brightness,
      surface: baseSurface,
      primary: isDark
          ? InspectorColors.primaryDark
          : InspectorColors.primaryLight,
      secondary: isDark
          ? InspectorColors.accentDark
          : InspectorColors.accentLight,
      surfaceContainerLowest: isDark
          ? const Color(0xFF101A2E)
          : Colors.white.withValues(alpha: 0.82),
      surfaceContainerLow: isDark
          ? const Color(0xFF142139)
          : InspectorColors.surfaceTint,
      surfaceContainer: isDark
          ? const Color(0xFF192844)
          : const Color(0xFFEFF3FB),
      surfaceContainerHigh: isDark
          ? const Color(0xFF1F304D)
          : const Color(0xFFE8EDF7),
      surfaceContainerHighest: isDark
          ? const Color(0xFF263650)
          : const Color(0xFFE1E8F4),
      outline: isDark ? InspectorColors.dividerDark : const Color(0xFFC9D4E6),
      outlineVariant: isDark
          ? InspectorColors.dividerDark
          : InspectorColors.dividerLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontRoboto,
      scaffoldBackgroundColor: baseSurface,
      canvasColor: baseSurface,
      cardTheme: CardThemeData(
        color: isDark ? InspectorColors.cardDark : InspectorColors.cardLight,
        elevation: isDark ? 0 : 2,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : const Color(0xFF6274A0).withValues(alpha: 0.09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? InspectorColors.dividerDark
                : InspectorColors.glassHighlight,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? InspectorColors.surfaceDark
            : InspectorColors.surface.withValues(alpha: 0.94),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
        dividerColor: isDark
            ? InspectorColors.dividerDark
            : InspectorColors.dividerLight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest
            : Colors.white.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
        tileColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? InspectorColors.dividerDark
            : InspectorColors.dividerLight,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? scheme.surfaceContainerHigh
            : Colors.white.withValues(alpha: 0.7),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      extensions: const [],
    );
  }
}
