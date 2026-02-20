import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/ui_sizes.dart';
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

  /// Get resources pane text scale
  double get resourcesTextScale => _settings.resourcesTextScale;

  /// Get UI sizes configuration
  UiSizes get uiSizes => _settings.uiSizes;

  /// Update UI category scale
  Future<void> setUiCategoryScale(String category, TextSizePreset preset) async {
    UiSizes newUiSizes;
    switch (category) {
      case 'paneHeaders':
        newUiSizes = _settings.uiSizes.copyWith(paneHeaders: preset);
      case 'tasksPane':
        newUiSizes = _settings.uiSizes.copyWith(tasksPane: preset);
      case 'historyPane':
        newUiSizes = _settings.uiSizes.copyWith(historyPane: preset);
      case 'logView':
        newUiSizes = _settings.uiSizes.copyWith(logView: preset);
      case 'terminal':
        newUiSizes = _settings.uiSizes.copyWith(terminal: preset);
      case 'toolbar':
        newUiSizes = _settings.uiSizes.copyWith(toolbar: preset);
      default:
        return;
    }
    _settings = _settings.copyWith(uiSizes: newUiSizes);
    _core.notify();
    await _save();
  }

  /// Reset UI sizes to defaults
  Future<void> resetUiSizes() async {
    _settings = _settings.copyWith(uiSizes: UiSizes.defaults());
    _core.notify();
    await _save();
  }

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

  /// Update resources pane text size preset
  Future<void> setResourcesTextSizePreset(TextSizePreset preset) async {
    if (_settings.resourcesTextSizePreset == preset) return;
    _settings = _settings.copyWith(resourcesTextSizePreset: preset);
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

  // === API SETTINGS ===

  /// Enable or disable the API server
  Future<void> setApiEnabled(bool enabled) async {
    if (_settings.apiEnabled == enabled) return;
    _settings = _settings.copyWith(apiEnabled: enabled);
    _core.notify();
    await _save();
  }

  /// Set the API server port
  Future<void> setApiPort(int port) async {
    final clamped = port.clamp(1024, 65535);
    if (_settings.apiPort == clamped) return;
    _settings = _settings.copyWith(apiPort: clamped);
    _core.notify();
    await _save();
  }

  /// Add an allowed Ethereum address
  Future<void> addApiAllowedAddress(String address) async {
    final normalized = address.toLowerCase();
    if (_settings.apiAllowedAddresses.contains(normalized)) return;
    _settings = _settings.copyWith(
      apiAllowedAddresses: [..._settings.apiAllowedAddresses, normalized],
    );
    _core.notify();
    await _save();
  }

  /// Remove an allowed Ethereum address
  Future<void> removeApiAllowedAddress(String address) async {
    final normalized = address.toLowerCase();
    if (!_settings.apiAllowedAddresses.contains(normalized)) return;
    _settings = _settings.copyWith(
      apiAllowedAddresses:
          _settings.apiAllowedAddresses.where((a) => a != normalized).toList(),
    );
    _core.notify();
    await _save();
  }

  /// Enable or disable a specific API endpoint
  Future<void> setApiEndpointEnabled(String endpoint, bool enabled) async {
    final toggles = Map<String, bool>.from(_settings.apiEndpointToggles);
    toggles[endpoint] = enabled;
    _settings = _settings.copyWith(apiEndpointToggles: toggles);
    _core.notify();
    await _save();
  }

  /// Set the timestamp tolerance for API requests (in seconds)
  Future<void> setApiTimestampTolerance(int seconds) async {
    final clamped = seconds.clamp(30, 3600);
    if (_settings.apiTimestampTolerance == clamped) return;
    _settings = _settings.copyWith(apiTimestampTolerance: clamped);
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
