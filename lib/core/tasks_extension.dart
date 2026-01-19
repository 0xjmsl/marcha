import '../models/task.dart';
import '../models/template.dart';
import 'core.dart';

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
