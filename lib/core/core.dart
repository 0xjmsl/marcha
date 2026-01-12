import 'dart:io';
import 'package:flutter/foundation.dart';
import 'templates_extension.dart';
import 'tasks_extension.dart';
import 'layout_extension.dart';
import 'history_extension.dart';
import 'settings_extension.dart';
import 'logs_extension.dart';

/// Core monolith - single source of truth for all app state
class Core extends ChangeNotifier {
  static final Core _instance = Core._internal();
  static Core get instance => _instance;

  Core._internal() {
    _templates = TemplatesExtension(this);
    _tasks = TasksExtension(this);
    _layout = LayoutExtension(this);
    _history = HistoryExtension(this);
    _settings = SettingsExtension(this);
    _logs = LogsExtension(this);
  }

  late final TemplatesExtension _templates;
  late final TasksExtension _tasks;
  late final LayoutExtension _layout;
  late final HistoryExtension _history;
  late final SettingsExtension _settings;
  late final LogsExtension _logs;

  TemplatesExtension get templates => _templates;
  TasksExtension get tasks => _tasks;
  LayoutExtension get layout => _layout;
  HistoryExtension get history => _history;
  SettingsExtension get settings => _settings;
  LogsExtension get logs => _logs;

  // Data directory
  static String _dataDir = '';
  static String get dataDir => _dataDir;

  // Initialization state
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize core - call once at app startup
  Future<void> initialize() async {
    if (_initialized) return;

    // Set up data directory
    final appData = Platform.environment['APPDATA'] ?? '.';
    final marchaDir = Directory('$appData\\Marcha');
    if (!await marchaDir.exists()) {
      await marchaDir.create(recursive: true);
    }
    _dataDir = marchaDir.path;

    // Load persisted data
    await _settings.load();
    await _templates.load();
    await _history.load();
    await _logs.initialize();

    _initialized = true;
    notify();
  }

  /// Notify listeners that state has changed
  void notify() {
    notifyListeners();
  }
}

/// Shorthand access to Core
Core get core => Core.instance;
