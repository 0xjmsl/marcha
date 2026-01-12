import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/history_entry.dart';
import '../models/template.dart';
import 'core.dart';

/// Extension managing task history
class HistoryExtension {
  final Core _core;

  HistoryExtension(this._core);

  static const String _historyFileName = 'history.json';

  String get _historyFilePath => '${Core.dataDir}\\$_historyFileName';

  List<HistoryEntry> _entries = [];

  /// Get all history entries (excluding archived)
  List<HistoryEntry> get all =>
      _entries.where((e) => !e.isArchived).toList();

  /// Get all entries including archived
  List<HistoryEntry> get allWithArchived => List.unmodifiable(_entries);

  /// Get running entries
  List<HistoryEntry> get running =>
      _entries.where((e) => e.isRunning).toList();

  /// Get archived entries
  List<HistoryEntry> get archived =>
      _entries.where((e) => e.isArchived).toList();

  /// Get entry by id
  HistoryEntry? getById(String id) {
    return _entries.where((e) => e.id == id).firstOrNull;
  }

  /// Create a new history entry from a template launch
  Future<HistoryEntry> add(Template template, String taskId) async {
    final entry = HistoryEntry(
      id: HistoryEntry.generateId(),
      name: template.name,
      command: template.command,
      arguments: template.arguments,
      workingDirectory: template.workingDirectory,
      templateId: template.id,
      taskId: taskId,
      startedAt: DateTime.now(),
      emoji: template.emoji,
    );
    _entries.insert(0, entry); // Most recent first
    _core.notify();
    await _save();
    return entry;
  }

  /// Mark entry as completed
  Future<void> complete(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _entries[index] = _entries[index].copyWith(
        status: HistoryStatus.completed,
        endedAt: DateTime.now(),
      );
      _core.notify();
      await _save();
    }
  }

  /// Mark entry as stopped
  Future<void> stop(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _entries[index] = _entries[index].copyWith(
        status: HistoryStatus.stopped,
        endedAt: DateTime.now(),
      );
      _core.notify();
      await _save();
    }
  }

  /// Mark entry as error
  Future<void> error(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _entries[index] = _entries[index].copyWith(
        status: HistoryStatus.error,
        endedAt: DateTime.now(),
      );
      _core.notify();
      await _save();
    }
  }

  /// Archive an entry (soft delete)
  Future<void> archive(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) {
      _entries[index] = _entries[index].copyWith(
        status: HistoryStatus.archived,
      );
      _core.notify();
      await _save();
    }
  }

  /// Permanently remove an entry
  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _core.notify();
    await _save();
  }

  /// Clear all non-running entries
  Future<void> clearCompleted() async {
    _entries.removeWhere((e) => !e.isRunning);
    _core.notify();
    await _save();
  }

  /// Clear all archived entries
  Future<void> clearArchived() async {
    _entries.removeWhere((e) => e.isArchived);
    _core.notify();
    await _save();
  }

  // === PERSISTENCE ===

  /// Load history from disk
  Future<void> load() async {
    try {
      final file = File(_historyFilePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = json.decode(jsonString);
        _entries = jsonList.map((j) => HistoryEntry.fromJson(j)).toList();

        // Sort by startedAt descending (newest first)
        _entries.sort((a, b) => b.startedAt.compareTo(a.startedAt));

        // Mark any "running" entries as "stopped" (no process survives restart)
        bool needsSave = false;
        for (int i = 0; i < _entries.length; i++) {
          if (_entries[i].isRunning) {
            _entries[i] = _entries[i].copyWith(
              status: HistoryStatus.stopped,
              endedAt: DateTime.now(),
            );
            needsSave = true;
          }
        }

        if (needsSave) {
          await _save();
        }

        debugPrint('HistoryExtension: Loaded ${_entries.length} entries');
      }
    } catch (e) {
      debugPrint('HistoryExtension: Error loading history: $e');
      _entries = [];
    }
  }

  /// Save history to disk
  Future<void> _save() async {
    try {
      final file = File(_historyFilePath);
      final jsonString = json.encode(_entries.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('HistoryExtension: Error saving history: $e');
    }
  }
}
