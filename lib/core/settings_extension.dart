import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../theme/terminal_theme.dart';
import 'core.dart';

/// Extension managing application settings
class SettingsExtension {
  final Core _core;

  SettingsExtension(this._core) {
    // Set up layout change callback for persistence
    _core.layout.onLayoutChanged = _onLayoutChanged;
  }

  Timer? _layoutSaveTimer;

  static const String _settingsFileName = 'settings.json';

  /// Absolute max tasks limit (failsafe)
  static const int absoluteMaxTasks = 50;

  String get _settingsFilePath => '${Core.dataDir}\\$_settingsFileName';

  AppSettings _settings = AppSettings.defaults();

  /// Get current settings
  AppSettings get current => _settings;

  /// Get current text scale
  double get textScale => _settings.textScale;

  /// Get current max concurrent tasks
  int get maxConcurrentTasks => _settings.maxConcurrentTasks;

  /// Get current terminal theme (searches both built-in and custom)
  TerminalTheme get terminalTheme {
    // First check custom themes
    final customTheme = _settings.customTerminalThemes
        .where((t) => t.id == _settings.terminalThemeId)
        .firstOrNull;
    if (customTheme != null) return customTheme;

    // Fall back to built-in themes
    return TerminalTheme.getById(_settings.terminalThemeId);
  }

  /// Get all available themes (built-in + custom)
  List<TerminalTheme> get allTerminalThemes => [
        ...TerminalTheme.builtInThemes,
        ..._settings.customTerminalThemes,
      ];

  /// Get terminal font scale
  double get terminalFontScale => _settings.terminalFontScale;

  /// Update terminal theme
  Future<void> setTerminalTheme(String themeId) async {
    if (_settings.terminalThemeId == themeId) return;
    _settings = _settings.copyWith(terminalThemeId: themeId);
    _core.notify();
    await _save();
  }

  /// Update terminal font size preset
  Future<void> setTerminalFontSizePreset(TextSizePreset preset) async {
    if (_settings.terminalFontSizePreset == preset) return;
    _settings = _settings.copyWith(terminalFontSizePreset: preset);
    _core.notify();
    await _save();
  }

  /// Save a custom terminal theme
  Future<void> saveCustomTerminalTheme(TerminalTheme theme) async {
    // Ensure it's marked as custom
    final customTheme = theme.copyWith(isBuiltIn: false);

    // Check if updating existing or adding new
    final existingIndex = _settings.customTerminalThemes
        .indexWhere((t) => t.id == customTheme.id);

    List<TerminalTheme> updatedThemes;
    if (existingIndex >= 0) {
      // Update existing
      updatedThemes = List.from(_settings.customTerminalThemes);
      updatedThemes[existingIndex] = customTheme;
    } else {
      // Add new
      updatedThemes = [..._settings.customTerminalThemes, customTheme];
    }

    _settings = _settings.copyWith(
      customTerminalThemes: updatedThemes,
      terminalThemeId: customTheme.id,
    );
    _core.notify();
    await _save();
  }

  /// Delete a custom terminal theme
  Future<void> deleteCustomTerminalTheme(String themeId) async {
    final updatedThemes = _settings.customTerminalThemes
        .where((t) => t.id != themeId)
        .toList();

    // If deleted theme was selected, switch to default
    String newThemeId = _settings.terminalThemeId;
    if (_settings.terminalThemeId == themeId) {
      newThemeId = 'default_dark';
    }

    _settings = _settings.copyWith(
      customTerminalThemes: updatedThemes,
      terminalThemeId: newThemeId,
    );
    _core.notify();
    await _save();
  }

  /// Update text size preset
  Future<void> setTextSizePreset(TextSizePreset preset) async {
    if (_settings.textSizePreset == preset) return;
    _settings = _settings.copyWith(textSizePreset: preset);
    _core.notify();
    await _save();
  }

  /// Update dark mode setting
  Future<void> setDarkMode(bool isDark) async {
    if (_settings.isDarkMode == isDark) return;
    _settings = _settings.copyWith(isDarkMode: isDark);
    _core.notify();
    await _save();
  }

  /// Update max concurrent tasks
  Future<void> setMaxConcurrentTasks(int maxTasks) async {
    final clamped = maxTasks.clamp(1, absoluteMaxTasks);
    if (_settings.maxConcurrentTasks == clamped) return;
    _settings = _settings.copyWith(maxConcurrentTasks: clamped);
    _core.notify();
    await _save();
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaults();
    _core.notify();
    await _save();
  }

  // === PERSISTENCE ===

  /// Load settings from disk
  Future<void> load() async {
    try {
      final file = File(_settingsFilePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _settings = AppSettings.fromJson(jsonMap);
        debugPrint('SettingsExtension: Loaded settings');
      } else {
        debugPrint('SettingsExtension: No settings file found, using defaults');
      }
    } catch (e) {
      debugPrint('SettingsExtension: Error loading settings: $e');
      _settings = AppSettings.defaults();
    }

    // Initialize layout from loaded settings
    _core.layout.initFromSettings(_settings);
  }

  /// Save settings to disk
  Future<void> _save() async {
    try {
      final file = File(_settingsFilePath);
      final jsonString = json.encode(_settings.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('SettingsExtension: Error saving settings: $e');
    }
  }

  // === LAYOUT PERSISTENCE ===

  /// Called when layout changes - debounced save
  void _onLayoutChanged() {
    // Cancel any pending save
    _layoutSaveTimer?.cancel();

    // Debounce: save 500ms after last change
    _layoutSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveLayoutState();
    });
  }

  /// Save current layout state to settings
  Future<void> _saveLayoutState() async {
    final layoutData = _core.layout.exportForSettings();

    _settings = _settings.copyWith(
      layoutPreset: layoutData.preset,
      slotAssignments: layoutData.slots,
      paneSizes: layoutData.sizes,
    );

    await _save();
    debugPrint('SettingsExtension: Saved layout state');
  }
}
