import 'package:material_ui/material_ui.dart';

/// Palette and shared design tokens for the isolated network inspector.
abstract final class InspectorColors {
  static const Color primary = Color(0xFF14B8A6);
  static const Color primaryDark = Color(0xFF0D9488);
  static const Color secondary = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = secondary;

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceSecondary = Color(0xFFF1F5F9);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightDivider = Color(0xFFF1F5F9);

  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceSecondary = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF1E293B);

  // Compatibility aliases used by existing widgets.
  static const Color seed = primary;
  static const Color seedAccent = secondary;
  static const Color brandNavy = darkBackground;
  static const Color brandBlue = secondary;
  static const Color brandCyan = primary;
  static const Color surface = lightBackground;
  static const Color cardLight = lightSurface;
  static const Color dividerLight = lightBorder;
  static const Color surfaceTint = lightSurfaceSecondary;
  static const Color glassHighlight = lightBorder;
  static const Color surfaceDark = darkBackground;
  static const Color cardDark = darkSurface;
  static const Color dividerDark = darkBorder;
  static const Color primaryLight = primary;
  static const Color accentLight = secondary;
  static const Color accentDark = secondary;
  static const Color brandTintLight = Color(0xFFE6FFFB);
  static const Color brandTintDark = Color(0xFF103B3A);

  static const Color get_ = Color(0xFF3B82F6);
  static const Color post = Color(0xFF10B981);
  static const Color put = Color(0xFFF59E0B);
  static const Color patch = Color(0xFF8B5CF6);
  static const Color delete = Color(0xFFEF4444);
  static const Color head = Color(0xFF06B6D4);
  static const Color options = Color(0xFF6366F1);
  static const Color other = Color(0xFF64748B);

  static const Color status2xx = Color(0xFF059669);
  static const Color status2xxBg = Color(0xFFD1FAE5);
  static const Color status3xx = Color(0xFF2563EB);
  static const Color status3xxBg = Color(0xFFDBEAFE);
  static const Color status4xx = Color(0xFFD97706);
  static const Color status4xxBg = Color(0xFFFEF3C7);
  static const Color status5xx = Color(0xFFDC2626);
  static const Color status5xxBg = Color(0xFFFEE2E2);
  static const Color statusError = Color(0xFFBE123C);
  static const Color statusErrorBg = Color(0xFFFFE4E6);
  static const Color statusPending = Color(0xFF64748B);
  static const Color statusPendingBg = Color(0xFFF1F5F9);
  static const Color status2xxDark = Color(0xFF34D399);
  static const Color status2xxBgDark = Color(0xFF064E3B);
  static const Color status3xxDark = Color(0xFF60A5FA);
  static const Color status3xxBgDark = Color(0xFF172554);
  static const Color status4xxDark = Color(0xFFFBBF24);
  static const Color status4xxBgDark = Color(0xFF78350F);
  static const Color status5xxDark = Color(0xFFFB7185);
  static const Color status5xxBgDark = Color(0xFF881337);
  static const Color statusErrorDark = Color(0xFFFDA4AF);
  static const Color statusErrorBgDark = Color(0xFF4C0519);

  static const Color jsonString = Color(0xFF059669);
  static const Color jsonNumber = Color(0xFF0284C7);
  static const Color jsonBool = Color(0xFFD97706);
  static const Color jsonNull = Color(0xFF64748B);
  static const Color jsonKey = Color(0xFF7C3AED);
  static const Color jsonStringDark = Color(0xFF6EE7B7);
  static const Color jsonNumberDark = Color(0xFF38BDF8);
  static const Color jsonBoolDark = Color(0xFFFCD34D);
  static const Color jsonNullDark = Color(0xFF94A3B8);
  static const Color jsonKeyDark = Color(0xFFC4B5FD);

  static Color methodColor(String method) => switch (method.toUpperCase()) {
    'GET' => get_,
    'POST' => post,
    'PUT' => put,
    'PATCH' => patch,
    'DELETE' => delete,
    'HEAD' => head,
    'OPTIONS' => options,
    _ => other,
  };

  static (Color fg, Color bg) statusColors(int? code, {required bool dark}) {
    if (code == null) {
      return dark
          ? (statusErrorDark, statusErrorBgDark)
          : (statusError, statusErrorBg);
    }
    if (code < 300) {
      return dark ? (status2xxDark, status2xxBgDark) : (status2xx, status2xxBg);
    }
    if (code < 400) {
      return dark ? (status3xxDark, status3xxBgDark) : (status3xx, status3xxBg);
    }
    if (code < 500) {
      return dark ? (status4xxDark, status4xxBgDark) : (status4xx, status4xxBg);
    }
    return dark ? (status5xxDark, status5xxBgDark) : (status5xx, status5xxBg);
  }
}
