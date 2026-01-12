import 'package:flutter/material.dart';

/// Terminal color theme configuration
class TerminalTheme {
  final String id;
  final String name;
  final bool isBuiltIn;

  // Background colors
  final Color background;
  final Color inputAreaBackground;
  final Color titleBarBackground;
  final Color borderColor;

  // Text colors
  final Color foreground;
  final Color timestampColor;

  // Semantic output colors
  final Color errorColor;
  final Color warningColor;
  final Color successColor;
  final Color promptColor;
  final Color exitCodeColor;

  // Traffic light / status colors
  final Color closeButtonColor;
  final Color minimizeButtonColor;
  final Color scrollButtonColor;
  final Color runningColor;
  final Color stoppedColor;

  const TerminalTheme({
    required this.id,
    required this.name,
    this.isBuiltIn = true,
    required this.background,
    required this.inputAreaBackground,
    required this.titleBarBackground,
    required this.borderColor,
    required this.foreground,
    required this.timestampColor,
    required this.errorColor,
    required this.warningColor,
    required this.successColor,
    required this.promptColor,
    required this.exitCodeColor,
    required this.closeButtonColor,
    required this.minimizeButtonColor,
    required this.scrollButtonColor,
    required this.runningColor,
    required this.stoppedColor,
  });

  /// Create from JSON map (for custom themes)
  factory TerminalTheme.fromJson(Map<String, dynamic> json) {
    return TerminalTheme(
      id: json['id'] as String,
      name: json['name'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      background: Color(json['background'] as int),
      inputAreaBackground: Color(json['inputAreaBackground'] as int),
      titleBarBackground: Color(json['titleBarBackground'] as int),
      borderColor: Color(json['borderColor'] as int),
      foreground: Color(json['foreground'] as int),
      timestampColor: Color(json['timestampColor'] as int),
      errorColor: Color(json['errorColor'] as int),
      warningColor: Color(json['warningColor'] as int),
      successColor: Color(json['successColor'] as int),
      promptColor: Color(json['promptColor'] as int),
      exitCodeColor: Color(json['exitCodeColor'] as int),
      closeButtonColor: Color(json['closeButtonColor'] as int),
      minimizeButtonColor: Color(json['minimizeButtonColor'] as int),
      scrollButtonColor: Color(json['scrollButtonColor'] as int),
      runningColor: Color(json['runningColor'] as int),
      stoppedColor: Color(json['stoppedColor'] as int),
    );
  }

  /// Convert to JSON map (for persistence)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isBuiltIn': isBuiltIn,
        'background': background.toARGB32(),
        'inputAreaBackground': inputAreaBackground.toARGB32(),
        'titleBarBackground': titleBarBackground.toARGB32(),
        'borderColor': borderColor.toARGB32(),
        'foreground': foreground.toARGB32(),
        'timestampColor': timestampColor.toARGB32(),
        'errorColor': errorColor.toARGB32(),
        'warningColor': warningColor.toARGB32(),
        'successColor': successColor.toARGB32(),
        'promptColor': promptColor.toARGB32(),
        'exitCodeColor': exitCodeColor.toARGB32(),
        'closeButtonColor': closeButtonColor.toARGB32(),
        'minimizeButtonColor': minimizeButtonColor.toARGB32(),
        'scrollButtonColor': scrollButtonColor.toARGB32(),
        'runningColor': runningColor.toARGB32(),
        'stoppedColor': stoppedColor.toARGB32(),
      };

  /// Create copy with optional overrides
  TerminalTheme copyWith({
    String? id,
    String? name,
    bool? isBuiltIn,
    Color? background,
    Color? inputAreaBackground,
    Color? titleBarBackground,
    Color? borderColor,
    Color? foreground,
    Color? timestampColor,
    Color? errorColor,
    Color? warningColor,
    Color? successColor,
    Color? promptColor,
    Color? exitCodeColor,
    Color? closeButtonColor,
    Color? minimizeButtonColor,
    Color? scrollButtonColor,
    Color? runningColor,
    Color? stoppedColor,
  }) {
    return TerminalTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      background: background ?? this.background,
      inputAreaBackground: inputAreaBackground ?? this.inputAreaBackground,
      titleBarBackground: titleBarBackground ?? this.titleBarBackground,
      borderColor: borderColor ?? this.borderColor,
      foreground: foreground ?? this.foreground,
      timestampColor: timestampColor ?? this.timestampColor,
      errorColor: errorColor ?? this.errorColor,
      warningColor: warningColor ?? this.warningColor,
      successColor: successColor ?? this.successColor,
      promptColor: promptColor ?? this.promptColor,
      exitCodeColor: exitCodeColor ?? this.exitCodeColor,
      closeButtonColor: closeButtonColor ?? this.closeButtonColor,
      minimizeButtonColor: minimizeButtonColor ?? this.minimizeButtonColor,
      scrollButtonColor: scrollButtonColor ?? this.scrollButtonColor,
      runningColor: runningColor ?? this.runningColor,
      stoppedColor: stoppedColor ?? this.stoppedColor,
    );
  }

  /// Default dark theme
  factory TerminalTheme.defaultDark() => const TerminalTheme(
        id: 'default_dark',
        name: 'Default Dark',
        isBuiltIn: true,
        background: Color(0xFF1E1E1E),
        inputAreaBackground: Color(0xFF2D2D2D),
        titleBarBackground: Color(0xFF323232),
        borderColor: Color(0xFF3C3C3C),
        foreground: Color(0xFFCCCCCC),
        timestampColor: Color(0xFF6A6A6A),
        errorColor: Color(0xFFFF6B6B),
        warningColor: Color(0xFFFFE66D),
        successColor: Color(0xFF4ECB71),
        promptColor: Color(0xFF9CDCFE),
        exitCodeColor: Color(0xFFFFAB40),
        closeButtonColor: Color(0xFFFF5F56),
        minimizeButtonColor: Color(0xFFFFBD2E),
        scrollButtonColor: Color(0xFF27CA40),
        runningColor: Color(0xFF27CA40),
        stoppedColor: Color(0xFFFF5F56),
      );

  /// Solarized Dark theme
  factory TerminalTheme.solarizedDark() => const TerminalTheme(
        id: 'solarized_dark',
        name: 'Solarized Dark',
        isBuiltIn: true,
        background: Color(0xFF002B36),
        inputAreaBackground: Color(0xFF073642),
        titleBarBackground: Color(0xFF073642),
        borderColor: Color(0xFF586E75),
        foreground: Color(0xFF839496),
        timestampColor: Color(0xFF586E75),
        errorColor: Color(0xFFDC322F),
        warningColor: Color(0xFFB58900),
        successColor: Color(0xFF859900),
        promptColor: Color(0xFF268BD2),
        exitCodeColor: Color(0xFFCB4B16),
        closeButtonColor: Color(0xFFDC322F),
        minimizeButtonColor: Color(0xFFB58900),
        scrollButtonColor: Color(0xFF859900),
        runningColor: Color(0xFF859900),
        stoppedColor: Color(0xFFDC322F),
      );

  /// Monokai theme
  factory TerminalTheme.monokai() => const TerminalTheme(
        id: 'monokai',
        name: 'Monokai',
        isBuiltIn: true,
        background: Color(0xFF272822),
        inputAreaBackground: Color(0xFF3E3D32),
        titleBarBackground: Color(0xFF3E3D32),
        borderColor: Color(0xFF75715E),
        foreground: Color(0xFFF8F8F2),
        timestampColor: Color(0xFF75715E),
        errorColor: Color(0xFFF92672),
        warningColor: Color(0xFFE6DB74),
        successColor: Color(0xFFA6E22E),
        promptColor: Color(0xFF66D9EF),
        exitCodeColor: Color(0xFFFD971F),
        closeButtonColor: Color(0xFFF92672),
        minimizeButtonColor: Color(0xFFE6DB74),
        scrollButtonColor: Color(0xFFA6E22E),
        runningColor: Color(0xFFA6E22E),
        stoppedColor: Color(0xFFF92672),
      );

  /// Nord theme
  factory TerminalTheme.nord() => const TerminalTheme(
        id: 'nord',
        name: 'Nord',
        isBuiltIn: true,
        background: Color(0xFF2E3440),
        inputAreaBackground: Color(0xFF3B4252),
        titleBarBackground: Color(0xFF3B4252),
        borderColor: Color(0xFF4C566A),
        foreground: Color(0xFFD8DEE9),
        timestampColor: Color(0xFF4C566A),
        errorColor: Color(0xFFBF616A),
        warningColor: Color(0xFFEBCB8B),
        successColor: Color(0xFFA3BE8C),
        promptColor: Color(0xFF81A1C1),
        exitCodeColor: Color(0xFFD08770),
        closeButtonColor: Color(0xFFBF616A),
        minimizeButtonColor: Color(0xFFEBCB8B),
        scrollButtonColor: Color(0xFFA3BE8C),
        runningColor: Color(0xFFA3BE8C),
        stoppedColor: Color(0xFFBF616A),
      );

  /// Dracula theme
  factory TerminalTheme.dracula() => const TerminalTheme(
        id: 'dracula',
        name: 'Dracula',
        isBuiltIn: true,
        background: Color(0xFF282A36),
        inputAreaBackground: Color(0xFF44475A),
        titleBarBackground: Color(0xFF44475A),
        borderColor: Color(0xFF6272A4),
        foreground: Color(0xFFF8F8F2),
        timestampColor: Color(0xFF6272A4),
        errorColor: Color(0xFFFF5555),
        warningColor: Color(0xFFF1FA8C),
        successColor: Color(0xFF50FA7B),
        promptColor: Color(0xFF8BE9FD),
        exitCodeColor: Color(0xFFFFB86C),
        closeButtonColor: Color(0xFFFF5555),
        minimizeButtonColor: Color(0xFFF1FA8C),
        scrollButtonColor: Color(0xFF50FA7B),
        runningColor: Color(0xFF50FA7B),
        stoppedColor: Color(0xFFFF5555),
      );

  /// Default light theme
  factory TerminalTheme.defaultLight() => const TerminalTheme(
        id: 'default_light',
        name: 'Default Light',
        isBuiltIn: true,
        background: Color(0xFFF5F5F5),
        inputAreaBackground: Color(0xFFFFFFFF),
        titleBarBackground: Color(0xFFE8E8E8),
        borderColor: Color(0xFFD4D4D4),
        foreground: Color(0xFF1E1E1E),
        timestampColor: Color(0xFF9E9E9E),
        errorColor: Color(0xFFD32F2F),
        warningColor: Color(0xFFF57C00),
        successColor: Color(0xFF388E3C),
        promptColor: Color(0xFF1976D2),
        exitCodeColor: Color(0xFFE64A19),
        closeButtonColor: Color(0xFFD32F2F),
        minimizeButtonColor: Color(0xFFF57C00),
        scrollButtonColor: Color(0xFF388E3C),
        runningColor: Color(0xFF388E3C),
        stoppedColor: Color(0xFFD32F2F),
      );

  /// Solarized Light theme
  factory TerminalTheme.solarizedLight() => const TerminalTheme(
        id: 'solarized_light',
        name: 'Solarized Light',
        isBuiltIn: true,
        background: Color(0xFFFDF6E3),
        inputAreaBackground: Color(0xFFEEE8D5),
        titleBarBackground: Color(0xFFEEE8D5),
        borderColor: Color(0xFF93A1A1),
        foreground: Color(0xFF657B83),
        timestampColor: Color(0xFF93A1A1),
        errorColor: Color(0xFFDC322F),
        warningColor: Color(0xFFB58900),
        successColor: Color(0xFF859900),
        promptColor: Color(0xFF268BD2),
        exitCodeColor: Color(0xFFCB4B16),
        closeButtonColor: Color(0xFFDC322F),
        minimizeButtonColor: Color(0xFFB58900),
        scrollButtonColor: Color(0xFF859900),
        runningColor: Color(0xFF859900),
        stoppedColor: Color(0xFFDC322F),
      );

  /// All built-in themes
  static List<TerminalTheme> get builtInThemes => [
        TerminalTheme.defaultDark(),
        TerminalTheme.defaultLight(),
        TerminalTheme.solarizedDark(),
        TerminalTheme.solarizedLight(),
        TerminalTheme.monokai(),
        TerminalTheme.nord(),
        TerminalTheme.dracula(),
      ];

  /// Get theme by ID
  static TerminalTheme getById(String id) {
    return builtInThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => TerminalTheme.defaultDark(),
    );
  }
}
