import 'package:flutter/material.dart';

/// Color palette for Marcha - supports both dark and light themes
class AppColors {
  AppColors._();

  // === DARK THEME COLORS ===
  static const _darkBackground = Color(0xFF1E1E1E);
  static const _darkSurface = Color(0xFF252526);
  static const _darkSurfaceLight = Color(0xFF2D2D2D);
  static const _darkSurfaceLighter = Color(0xFF323232);
  static const _darkSurfaceBright = Color(0xFF3C3C3C);
  static const _darkBorder = Color(0xFF3C3C3C);
  static const _darkBorderLight = Color(0xFF4A4A4A);
  static const _darkTextPrimary = Color(0xFFCCCCCC);
  static const _darkTextSecondary = Color(0xFF9D9D9D);
  static const _darkTextMuted = Color(0xFF6A6A6A);
  static const _darkTextBright = Color(0xFFFFFFFF);
  static const _darkSidebarBackground = Color(0xFF252526);
  static const _darkSidebarSelected = Color(0xFF37373D);
  static const _darkSidebarHover = Color(0xFF2A2D2E);
  static const _darkCardBackground = Color(0xFF2D2D2D);
  static const _darkCardHover = Color(0xFF323232);
  static const _darkCardSelected = Color(0xFF37373D);
  static const _darkScrollbar = Color(0xFF5A5A5A);
  static const _darkScrollbarHover = Color(0xFF7A7A7A);

  // === LIGHT THEME COLORS ===
  static const _lightBackground = Color(0xFFF3F3F3);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightSurfaceLight = Color(0xFFF5F5F5);
  static const _lightSurfaceLighter = Color(0xFFEAEAEA);
  static const _lightSurfaceBright = Color(0xFFE0E0E0);
  static const _lightBorder = Color(0xFFD4D4D4);
  static const _lightBorderLight = Color(0xFFE0E0E0);
  static const _lightTextPrimary = Color(0xFF1E1E1E);
  static const _lightTextSecondary = Color(0xFF616161);
  static const _lightTextMuted = Color(0xFF9E9E9E);
  static const _lightTextBright = Color(0xFF000000);
  static const _lightSidebarBackground = Color(0xFFFFFFFF);
  static const _lightSidebarSelected = Color(0xFFE8E8E8);
  static const _lightSidebarHover = Color(0xFFF0F0F0);
  static const _lightCardBackground = Color(0xFFFFFFFF);
  static const _lightCardHover = Color(0xFFF5F5F5);
  static const _lightCardSelected = Color(0xFFE8E8E8);
  static const _lightScrollbar = Color(0xFFBDBDBD);
  static const _lightScrollbarHover = Color(0xFF9E9E9E);

  // === STATUS COLORS (same for both themes) ===
  static const Color running = Color(0xFF27CA40);
  static const Color runningDim = Color(0xFF4ECB71);
  static const Color stopped = Color(0xFFFF5F56);
  static const Color stoppedDim = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFBD2E);
  static const Color warningDim = Color(0xFFFFE66D);
  static const Color scheduled = Color(0xFFFFAB40);
  static const Color info = Color(0xFF0078D4);
  static const Color infoDim = Color(0xFF9CDCFE);
  static const Color success = Color(0xFF27CA40);
  static const Color error = Color(0xFFFF5F56);

  // Accent (for selections, highlights)
  static const Color accent = Color(0xFF0078D4);
  static const Color accentDim = Color(0xFF264F78);

  // Status with transparency for backgrounds
  static Color runningBackground = running.withValues(alpha: 0.15);
  static Color stoppedBackground = stopped.withValues(alpha: 0.15);
  static Color scheduledBackground = scheduled.withValues(alpha: 0.15);
  static Color warningBackground = warning.withValues(alpha: 0.15);

  // === THEME-AWARE GETTERS ===
  // These are kept for backward compatibility but prefer using Theme.of(context)

  // Legacy static colors (dark theme) - for backward compatibility
  static const Color background = _darkBackground;
  static const Color surface = _darkSurface;
  static const Color surfaceLight = _darkSurfaceLight;
  static const Color surfaceLighter = _darkSurfaceLighter;
  static const Color surfaceBright = _darkSurfaceBright;
  static const Color border = _darkBorder;
  static const Color borderLight = _darkBorderLight;
  static const Color textPrimary = _darkTextPrimary;
  static const Color textSecondary = _darkTextSecondary;
  static const Color textMuted = _darkTextMuted;
  static const Color textBright = _darkTextBright;
  static const Color sidebarBackground = _darkSidebarBackground;
  static const Color sidebarSelected = _darkSidebarSelected;
  static const Color sidebarHover = _darkSidebarHover;
  static const Color cardBackground = _darkCardBackground;
  static const Color cardHover = _darkCardHover;
  static const Color cardSelected = _darkCardSelected;
  static const Color scrollbar = _darkScrollbar;
  static const Color scrollbarHover = _darkScrollbarHover;

  // === THEME DATA ACCESS ===

  /// Get colors for dark theme
  static AppColorScheme get dark => const AppColorScheme(
    brightness: Brightness.dark,
    background: _darkBackground,
    surface: _darkSurface,
    surfaceLight: _darkSurfaceLight,
    surfaceLighter: _darkSurfaceLighter,
    surfaceBright: _darkSurfaceBright,
    border: _darkBorder,
    borderLight: _darkBorderLight,
    textPrimary: _darkTextPrimary,
    textSecondary: _darkTextSecondary,
    textMuted: _darkTextMuted,
    textBright: _darkTextBright,
    sidebarBackground: _darkSidebarBackground,
    sidebarSelected: _darkSidebarSelected,
    sidebarHover: _darkSidebarHover,
    cardBackground: _darkCardBackground,
    cardHover: _darkCardHover,
    cardSelected: _darkCardSelected,
    scrollbar: _darkScrollbar,
    scrollbarHover: _darkScrollbarHover,
  );

  /// Get colors for light theme
  static AppColorScheme get light => const AppColorScheme(
    brightness: Brightness.light,
    background: _lightBackground,
    surface: _lightSurface,
    surfaceLight: _lightSurfaceLight,
    surfaceLighter: _lightSurfaceLighter,
    surfaceBright: _lightSurfaceBright,
    border: _lightBorder,
    borderLight: _lightBorderLight,
    textPrimary: _lightTextPrimary,
    textSecondary: _lightTextSecondary,
    textMuted: _lightTextMuted,
    textBright: _lightTextBright,
    sidebarBackground: _lightSidebarBackground,
    sidebarSelected: _lightSidebarSelected,
    sidebarHover: _lightSidebarHover,
    cardBackground: _lightCardBackground,
    cardHover: _lightCardHover,
    cardSelected: _lightCardSelected,
    scrollbar: _lightScrollbar,
    scrollbarHover: _lightScrollbarHover,
  );

  /// Get colors based on brightness
  static AppColorScheme scheme(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

/// Theme-specific color scheme
class AppColorScheme {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color surfaceLighter;
  final Color surfaceBright;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textBright;
  final Color sidebarBackground;
  final Color sidebarSelected;
  final Color sidebarHover;
  final Color cardBackground;
  final Color cardHover;
  final Color cardSelected;
  final Color scrollbar;
  final Color scrollbarHover;

  const AppColorScheme({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.surfaceLighter,
    required this.surfaceBright,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textBright,
    required this.sidebarBackground,
    required this.sidebarSelected,
    required this.sidebarHover,
    required this.cardBackground,
    required this.cardHover,
    required this.cardSelected,
    required this.scrollbar,
    required this.scrollbarHover,
  });

  bool get isDark => brightness == Brightness.dark;
  bool get isLight => brightness == Brightness.light;
}
