import 'package:material_ui/material_ui.dart';

import 'inspector_colors.dart';

/// Theme used by the inspector overlay, independent of the host app styling.
abstract final class InspectorTheme {
  static const String package = 'chucker_flutter_plus';
  static const String fontRoboto = 'packages/$package/Roboto';
  static const String fontMonospace = 'packages/$package/monospace';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    const primary = InspectorColors.primary;
    final bg = dark
        ? InspectorColors.darkBackground
        : InspectorColors.lightBackground;
    final surface = dark
        ? InspectorColors.darkSurface
        : InspectorColors.lightSurface;
    final secondarySurface = dark
        ? InspectorColors.darkSurfaceSecondary
        : InspectorColors.lightSurfaceSecondary;
    final text = dark ? InspectorColors.darkText : InspectorColors.lightText;
    final secondaryText = dark
        ? InspectorColors.darkTextSecondary
        : InspectorColors.lightTextSecondary;
    final border = dark
        ? InspectorColors.darkBorder
        : InspectorColors.lightBorder;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? const Color(0xFF2DD4BF) : primary,
      onPrimary: dark ? const Color(0xFF042F2E) : Colors.white,
      secondary: InspectorColors.secondary,
      onSecondary: Colors.white,
      error: InspectorColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
    );

    final radius = BorderRadius.circular(12);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontRoboto,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      textTheme: Typography.material2021().black.apply(
        bodyColor: text,
        displayColor: text,
        fontFamily: fontRoboto,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontFamily: fontRoboto,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
        iconTheme: IconThemeData(color: secondaryText, size: 22),
        actionsIconTheme: IconThemeData(color: secondaryText),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: secondaryText,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13,
        ),
        dividerColor: border,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: secondaryText, fontSize: 14),
        prefixIconColor: secondaryText,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 0,
        tileColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: dark
            ? InspectorColors.darkDivider
            : InspectorColors.lightDivider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secondarySurface,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? scheme.onPrimary : null,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
