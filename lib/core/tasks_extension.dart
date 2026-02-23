import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/template.dart';
import 'core.dart';

/// A single step in an orchestrated restart sequence
class RestartStep {
  final String taskId;
  final int killDelayMs;
  final int startDelayMs;

  RestartStep({
    required this.taskId,
    this.killDelayMs = 0,
    this.startDelayMs = 0,
  });
}

/// Extension managing running and historic tasks
class TasksExtension {
  final Core _core;

  TasksExtension(this._core);

  final List<Task> _tasks = [];

  /// Get all tasks
  List<Task> get all => List.unmodifiable(_tasks);

  /// Get running tasks
  List<Task> get running => _tasks.where((t) => t.isRunning).toList();

  /// Get task by id
  Task? getById(String id) {
    return _tasks.where((t) => t.id == id).firstOrNull;
  }

  /// Create a task from a template and add it (does NOT start it)
  Task create(Template template) {
    final task = Task.fromTemplate(template);
    _tasks.add(task);
    _core.notify();
    return task;
  }

  /// Run a task by id - starts the PTY process
  void run(String id) {
    final task = getById(id);
    if (task == null || task.isRunning) return;

    // Set up exit handler
    task.onExit = () => _onTaskExit(id);

    // Clear previous stats and start
    task.clearStats();
    task.start();

    // Notify resource monitor that a task started
    _core.resourceMonitor.onTaskStarted(task);

    // Add to history if we have a template
    final template = task.templateId != null
        ? _core.templates.getById(task.templateId!)
        : null;
    if (template != null) {
      _core.history.add(template, task.id);
    }

    _core.notify();
  }

  void _onTaskExit(String taskId) {
    final task = getById(taskId);
    if (task != null) {
      _core.resourceMonitor.onTaskStopped(task);
    }
    _updateHistoryOnStop(taskId);
    _core.notify();
  }

  /// Create and immediately run a task from template
  Task launch(Template template) {
    final task = create(template);
    run(task.id);
    return task;
  }

  /// Create and run a task with placeholder values substituted
  Task launchWithValues(Template template, Map<String, String> placeholderValues) {
    final task = Task.fromTemplateWithValues(template, placeholderValues);
    _tasks.add(task);
    _core.notify();

    // Set up exit handler and start
    task.onExit = () => _onTaskExit(task.id);
    task.clearStats();
    task.start();

    // Notify resource monitor that a task started
    _core.resourceMonitor.onTaskStarted(task);

    // Add to history
    _core.history.add(template, task.id);
    _core.notify();

    return task;
  }

  /// Check if a template requires placeholder input before launching
  static bool requiresInput(Template template) {
    return template.placeholders.isNotEmpty;
  }

  /// Graceful stop (Ctrl+C)
  void stop(String id) {
    final task = getById(id);
    if (task == null || !task.isRunning) return;

    task.stop();
    _core.notify();
  }

  /// Force kill
  void kill(String id) {
    final task = getById(id);
    if (task == null) return;

    final wasRunning = task.isRunning;
    task.kill();

    if (wasRunning) {
      _core.resourceMonitor.onTaskStopped(task);
      _updateHistoryOnStop(id);
    }
    _core.notify();
  }

  /// Remove a task entirely
  void remove(String id) {
    final task = getById(id);
    if (task == null) return;

    if (task.isRunning) {
      task.kill();
      _core.resourceMonitor.onTaskStopped(task);
      _updateHistoryOnStop(id);
    }
    task.dispose();
    _tasks.removeWhere((t) => t.id == id);
    _core.notify();
  }

  /// Clear all stopped (non-running) tasks
  void clearStopped() {
    final stopped = _tasks.where((t) => !t.isRunning).toList();
    for (final task in stopped) {
      task.dispose();
    }
    _tasks.removeWhere((t) => !t.isRunning);
    _core.notify();
  }

  /// Orchestrated restart: kill and remove old tasks, then launch fresh ones
  Future<void> orchestrateRestart(List<RestartStep> sequence) async {
    debugPrint('TasksExtension: Starting restart sequence (${sequence.length} tasks)');

    // Phase 1: Kill in order, remembering template + pane slot for each
    final restartInfo = <({String? templateId, int? slotIndex, RestartStep step})>[];

    for (final step in sequence) {
      final task = getById(step.taskId);
      if (task == null) continue;

      final templateId = task.templateId;
      final slotIndex = _core.layout.findSlotByTaskId(step.taskId);

      restartInfo.add((templateId: templateId, slotIndex: slotIndex, step: step));

      if (task.isRunning) {
        debugPrint('TasksExtension: Killing ${step.taskId}');
        kill(step.taskId);
        await _waitForExit(step.taskId, timeoutMs: 10000);
      }

      // Fully remove the old task (dispose terminal, remove from list)
      debugPrint('TasksExtension: Removing old task ${step.taskId}');
      task.dispose();
      _tasks.removeWhere((t) => t.id == step.taskId);

      // Clear the pane so it looks like the process was closed
      if (slotIndex != null) {
        _core.layout.clearSlot(slotIndex);
      }

      _core.notify();

      if (step.killDelayMs > 0) {
        debugPrint('TasksExtension: Waiting ${step.killDelayMs}ms after kill');
        await Future.delayed(Duration(milliseconds: step.killDelayMs));
      }
    }

    // Phase 2: Launch fresh tasks from templates, assign to same pane slots
    for (final info in restartInfo) {
      if (info.templateId == null) {
        debugPrint('TasksExtension: Skipping ${info.step.taskId} — no template');
        continue;
      }

      final template = _core.templates.getById(info.templateId!);
      if (template == null) {
        debugPrint('TasksExtension: Template ${info.templateId} not found, skipping');
        continue;
      }

      debugPrint('TasksExtension: Launching fresh task from template ${template.name}');
      final newTask = launch(template);

      // Re-assign the new task to the same pane slot
      if (info.slotIndex != null) {
        _core.layout.assignTerminal(info.slotIndex!, newTask.id);
      }

      if (info.step.startDelayMs > 0) {
        debugPrint('TasksExtension: Waiting ${info.step.startDelayMs}ms after start');
        await Future.delayed(Duration(milliseconds: info.step.startDelayMs));
      }
    }

    debugPrint('TasksExtension: Restart sequence complete');
  }

  /// Poll until a task exits or timeout
  Future<void> _waitForExit(String taskId, {required int timeoutMs}) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(deadline)) {
      final task = getById(taskId);
      if (task == null || !task.isRunning) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
    debugPrint('TasksExtension: Timeout waiting for $taskId to exit');
  }

  void _updateHistoryOnStop(String taskId) {
    final task = getById(taskId);
    final historyEntry =
        _core.history.all.where((e) => e.taskId == taskId).firstOrNull;
    if (historyEntry != null) {
      // Save log before marking as stopped
      if (task != null) {
        _core.logs.save(historyEntry.id, task);
      }
      _core.history.stop(historyEntry.id);
    }
  }
}
