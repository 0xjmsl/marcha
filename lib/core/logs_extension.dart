import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/terminal_log.dart';
import '../models/task.dart';
import 'core.dart';

/// Extension managing terminal logs
class LogsExtension {
  // Kept for consistency with other extensions, may be used for future notify() calls
  // ignore: unused_field
  final Core _core;

  LogsExtension(this._core);

  static const String _logsDirName = 'logs';

  String get _logsDirPath => '${Core.dataDir}\\$_logsDirName';

  // In-memory cache of loaded logs
  final Map<String, TerminalLog> _cache = {};

  /// Initialize logs directory
  Future<void> initialize() async {
    final logsDir = Directory(_logsDirPath);
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
  }

  /// Save a log from a completed task
  Future<void> save(String historyId, Task task) async {
    try {
      final log = TerminalLog(
        id: historyId,
        name: task.name,
        command: task.command,
        arguments: task.arguments,
        workingDirectory: task.workingDirectory,
        startedAt: task.createdAt,
        endedAt: DateTime.now(),
        exitCode: task.exitCode,
        lines: task.logBuffer,
      );

      // Save to file
      final file = File('$_logsDirPath\\$historyId.json');
      await file.writeAsString(json.encode(log.toJson()));

      // Update cache
      _cache[historyId] = log;

      debugPrint('LogsExtension: Saved log for $historyId (${log.lines.length} lines)');
    } catch (e) {
      debugPrint('LogsExtension: Error saving log: $e');
    }
  }

  /// Get a log by history ID
  Future<TerminalLog?> get(String historyId) async {
    // Check cache first
    if (_cache.containsKey(historyId)) {
      return _cache[historyId];
    }

    // Try to load from file
    try {
      final file = File('$_logsDirPath\\$historyId.json');
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final log = TerminalLog.fromJson(json.decode(jsonString));
        _cache[historyId] = log;
        return log;
      }
    } catch (e) {
      debugPrint('LogsExtension: Error loading log $historyId: $e');
    }

    return null;
  }

  /// Check if a log exists
  Future<bool> exists(String historyId) async {
    if (_cache.containsKey(historyId)) return true;
    final file = File('$_logsDirPath\\$historyId.json');
    return file.exists();
  }

  /// Delete a log
  Future<void> delete(String historyId) async {
    try {
      _cache.remove(historyId);
      final file = File('$_logsDirPath\\$historyId.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('LogsExtension: Error deleting log $historyId: $e');
    }
  }

  /// Export log to a file
  Future<String?> export(String historyId, String filePath) async {
    try {
      final log = await get(historyId);
      if (log == null) return null;

      final file = File(filePath);
      await file.writeAsString(log.plainText);
      return filePath;
    } catch (e) {
      debugPrint('LogsExtension: Error exporting log: $e');
      return null;
    }
  }

  /// Clear all logs
  Future<void> clearAll() async {
    try {
      _cache.clear();
      final logsDir = Directory(_logsDirPath);
      if (await logsDir.exists()) {
        await for (final file in logsDir.list()) {
          if (file is File && file.path.endsWith('.json')) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('LogsExtension: Error clearing logs: $e');
    }
  }
}
