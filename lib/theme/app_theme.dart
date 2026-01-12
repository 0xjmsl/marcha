import 'package:flutter/material.dart';
import 'app_colors.dart';
import '../core/core.dart';

/// Terminal-inspired theme configuration for Marcha
class AppTheme {
  AppTheme._();

  // Font families
  static const String monoFont = 'Consolas';
  static const String defaultFont = 'Segoe UI';

  // Base font sizes (for small preset = 1.0 scale)
  static const double _monoSmallBase = 11;
  static const double _monoNormalBase = 13;
  static const double _monoLargeBase = 14;
  static const double _monoBoldBase = 13;
  static const double _bodySmallBase = 12;
  static const double _bodyNormalBase = 13;
  static const double _bodyLargeBase = 14;
  static const double _headingBase = 16;
  static const double _headingSmallBase = 14;
  static const double _sidebarLabelBase = 13;

  /// Get scaled text styles (uses Core settings)
  static AppTextStyles of(BuildContext context) {
    final scale = core.settings.textScale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppTextStyles(scale, isDark);
  }

  // === DARK THEME ===
  static ThemeData darkTheme = _buildTheme(AppColors.dark);

  // === LIGHT THEME ===
  static ThemeData lightTheme = _buildTheme(AppColors.light);

  /// Build ThemeData from color scheme
  static ThemeData _buildTheme(AppColorScheme colors) {
    final isDark = colors.isDark;

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.background,
      colorScheme: isDark
          ? ColorScheme.dark(
              surface: colors.surface,
              primary: AppColors.accent,
              onPrimary: colors.textBright,
              secondary: AppColors.info,
              onSecondary: colors.textBright,
              error: AppColors.stopped,
              onError: colors.textBright,
              onSurface: colors.textPrimary,
            )
          : ColorScheme.light(
              surface: colors.surface,
              primary: AppColors.accent,
              onPrimary: Colors.white,
              secondary: AppColors.info,
              onSecondary: Colors.white,
              error: AppColors.stopped,
              onError: Colors.white,
              onSurface: colors.textPrimary,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: monoFont,
          fontSize: 14,
          color: colors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: monoFont,
          fontSize: 16,
          color: colors.textBright,
          fontWeight: FontWeight.w600,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: colors.border, width: 1),
        ),
        textStyle: TextStyle(
          fontFamily: defaultFont,
          fontSize: 13,
          color: colors.textPrimary,
        ),
      ),
      iconTheme: IconThemeData(
        color: colors.textSecondary,
        size: 20,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.textSecondary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.info,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        labelStyle: TextStyle(
          fontFamily: defaultFont,
          fontSize: 13,
          color: colors.textSecondary,
        ),
        hintStyle: TextStyle(
          fontFamily: defaultFont,
          fontSize: 13,
          color: colors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return colors.scrollbarHover;
          }
          return colors.scrollbar;
        }),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(8),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceLighter,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        textStyle: TextStyle(
          fontFamily: monoFont,
          fontSize: 11,
          color: colors.textPrimary,
          height: 1.4,
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colors.textPrimary,
        iconColor: colors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      // Store color scheme in extensions for easy access
      extensions: [
        AppColorsExtension(colors),
      ],
    );
  }

  // Legacy static text styles (dark theme) - for backward compatibility
  static const TextStyle monoSmall = TextStyle(
    fontFamily: monoFont,
    fontSize: 11,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle monoNormal = TextStyle(
    fontFamily: monoFont,
    fontSize: 13,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle monoLarge = TextStyle(
    fontFamily: monoFont,
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle monoBold = TextStyle(
    fontFamily: monoFont,
    fontSize: 13,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.bold,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: defaultFont,
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyNormal = TextStyle(
    fontFamily: defaultFont,
    fontSize: 13,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: defaultFont,
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: monoFont,
    fontSize: 16,
    color: AppColors.textBright,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: monoFont,
    fontSize: 14,
    color: AppColors.textBright,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle sidebarLabel = TextStyle(
    fontFamily: defaultFont,
    fontSize: 13,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w400,
  );
}

/// Theme extension to access app-specific colors
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColorScheme colors;

  const AppColorsExtension(this.colors);

  @override
  AppColorsExtension copyWith({AppColorScheme? colors}) {
    return AppColorsExtension(colors ?? this.colors);
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return this;
  }

  /// Get from context
  static AppColorScheme of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorsExtension>();
    return ext?.colors ?? AppColors.dark;
  }
}

/// Scaled text styles and icon sizes wrapper
class AppTextStyles {
  final double scale;
  final bool isDark;

  const AppTextStyles(this.scale, [this.isDark = true]);

  AppColorScheme get _colors => isDark ? AppColors.dark : AppColors.light;

  // Scaled icon sizes
  double get iconTiny => 12 * scale;
  double get iconSmall => 16 * scale;
  double get iconNormal => 20 * scale;
  double get iconMedium => 24 * scale;
  double get iconLarge => 32 * scale;
  double get iconXLarge => 48 * scale;

  // Helper to scale any size
  double size(double baseSize) => baseSize * scale;

  TextStyle get monoSmall => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: AppTheme._monoSmallBase * scale,
        color: _colors.textPrimary,
        height: 1.4,
      );

  TextStyle get monoNormal => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: AppTheme._monoNormalBase * scale,
        color: _colors.textPrimary,
        height: 1.4,
      );

  TextStyle get monoLarge => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: AppTheme._monoLargeBase * scale,
        color: _colors.textPrimary,
        height: 1.4,
      );

  TextStyle get monoBold => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: AppTheme._monoBoldBase * scale,
        color: _colors.textPrimary,
        fontWeight: FontWeight.bold,
        height: 1.4,
      );

  TextStyle get bodySmall => TextStyle(
        fontFamily: AppTheme.defaultFont,
        fontSize: AppTheme._bodySmallBase * scale,
        color: _colors.textSecondary,
      );

  TextStyle get bodyNormal => TextStyle(
        fontFamily: AppTheme.defaultFont,
        fontSize: AppTheme._bodyNormalBase * scale,
        color: _colors.textPrimary,
      );

  TextStyle get bodyLarge => TextStyle(
        fontFamily: AppTheme.defaultFont,
        fontSize: AppTheme._bodyLargeBase * scale,
        color: _colors.textPrimary,
      );

  TextStyle get heading => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: AppTheme._headingBase * scale,
        color: _colors.textBright,
        fontWeight: FontWeight.w600,
      );

  TextStyle get headingSmall => TextStyle(
        fontFamily: AppTheme.monoFont,
        fontSize: AppTheme._headingSmallBase * scale,
        color: _colors.textBright,
        fontWeight: FontWeight.w500,
      );

  TextStyle get sidebarLabel => TextStyle(
        fontFamily: AppTheme.defaultFont,
        fontSize: AppTheme._sidebarLabelBase * scale,
        color: _colors.textPrimary,
        fontWeight: FontWeight.w400,
      );
}
