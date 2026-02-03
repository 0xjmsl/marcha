import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show VoidCallback;
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'template.dart';
import 'task_step.dart';
import 'process_stats.dart';
import '../services/native_bindings.dart';

enum TaskStatus {
  idle,
  running,
  stopped,
  error,
}

/// Status of step execution
enum StepExecutionStatus {
  idle,
  waitingForPattern,
  completed,
  timedOut,
}

/// A task is a running or historic process instance
class Task {
  final String id;
  final String name;
  final String command;
  final List<String> arguments;
  final String? workingDirectory;
  final DateTime createdAt;
  final String? templateId;
  final List<TaskStep> steps; // Automation steps

  // Terminal state (lives with the task, survives navigation)
  final xterm.Terminal terminal;
  final xterm.TerminalController terminalController;

  // Runtime process state (not serialized)
  Pty? _pty;
  int? _pid;
  int? _jobHandle; // Windows Job Object handle for process tree management
  int? _exitCode;
  StreamSubscription<Uint8List>? _outputSubscription;
  VoidCallback? onExit;

  // Step execution state
  int _currentStepIndex = 0;
  StepExecutionStatus _stepStatus = StepExecutionStatus.idle;
  Timer? _stepTimeoutTimer;
  String _outputBuffer = ''; // Buffer for pattern matching
  VoidCallback? onStepProgress; // Called when step status changes

  // Log buffer to capture terminal output for persistence
  final List<String> _logBuffer = [];
  String _logLineBuffer = ''; // Accumulates partial lines
  bool _logCaptureStarted = false; // Skip shell init output

  // Resource monitoring state (runtime only, not serialized)
  // Stats are pushed by the centralized ResourceMonitorExtension
  final List<ProcessStats> _statsHistory = [];
  final StreamController<ProcessStats> _statsController =
      StreamController<ProcessStats>.broadcast();

  int? get pid => _pid;
  int? get exitCode => _exitCode;
  bool get isRunning => _pid != null && _pty != null;
  TaskStatus get status => isRunning ? TaskStatus.running : TaskStatus.idle;
  List<String> get logBuffer => List.unmodifiable(_logBuffer);

  // Step execution getters
  bool get hasSteps => steps.isNotEmpty;
  int get currentStepIndex => _currentStepIndex;
  StepExecutionStatus get stepStatus => _stepStatus;
  TaskStep? get currentStep =>
      _currentStepIndex < steps.length ? steps[_currentStepIndex] : null;
  bool get stepsCompleted => _currentStepIndex >= steps.length;

  // Resource monitoring getters
  Stream<ProcessStats> get statsStream => _statsController.stream;
  List<ProcessStats> get statsHistory => List.unmodifiable(_statsHistory);
  ProcessStats? get latestStats =>
      _statsHistory.isNotEmpty ? _statsHistory.last : null;

  Task({
    required this.id,
    required this.name,
    required this.command,
    this.arguments = const [],
    this.workingDirectory,
    required this.createdAt,
    this.templateId,
    this.steps = const [],
  })  : terminal = xterm.Terminal(maxLines: 10000),
        terminalController = xterm.TerminalController() {
    // Wire terminal input to PTY (when PTY is started)
    terminal.onOutput = (data) {
      _pty?.write(const Utf8Encoder().convert(data));
    };
  }

  Task copyWith({
    String? id,
    String? name,
    String? command,
    List<String>? arguments,
    String? workingDirectory,
    DateTime? createdAt,
    String? templateId,
    List<TaskStep>? steps,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      arguments: arguments ?? this.arguments,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      createdAt: createdAt ?? this.createdAt,
      templateId: templateId ?? this.templateId,
      steps: steps ?? this.steps,
    );
  }

  /// Strip ANSI escape codes and control characters from text
  static String _stripAnsi(String text) {
    return text
        // All ANSI escape sequences: \x1b followed by [ and any params, ending with a letter
        .replaceAll(RegExp(r'\x1b\[[0-9;?]*[a-zA-Z]'), '')
        // OSC sequences (like title changes): \x1b] ... \x07 or \x1b\\
        .replaceAll(RegExp(r'\x1b\][^\x07]*(?:\x07|\x1b\\)'), '')
        // Other escape sequences
        .replaceAll(RegExp(r'\x1b[()][AB012]'), '')
        // Bell character
        .replaceAll('\x07', '')
        // Backspace
        .replaceAll('\x08', '')
        // Carriage return (keep newlines)
        .replaceAll('\r', '');
  }

  /// Start the PTY process
  void start() {
    if (isRunning) return;

    // Clear previous log buffer and reset capture state
    _logBuffer.clear();
    _logLineBuffer = '';
    _logCaptureStarted = false;

    // Write launch info to terminal only (not to log - log will have clean header)
    final timestamp = DateTime.now();
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final fullCommand = [command, ...arguments].join(' ');

    terminal.write('\x1b[90m[$timeStr]\x1b[0m Starting: \x1b[36m$name\x1b[0m\r\n');
    terminal.write('\x1b[90m>\x1b[0m \x1b[33m$fullCommand\x1b[0m\r\n');
    if (workingDirectory != null) {
      terminal.write('\x1b[90m@\x1b[0m \x1b[34m$workingDirectory\x1b[0m\r\n');
    }
    terminal.write('\x1b[90m${'─' * 50}\x1b[0m\r\n');

    final shell = 'cmd.exe';
    // Use terminal dimensions if available, otherwise reasonable defaults
    final cols = terminal.viewWidth > 0 ? terminal.viewWidth : 80;
    final rows = terminal.viewHeight > 0 ? terminal.viewHeight : 24;

    // Start shell without command - we'll send it after shell initializes
    _pty = Pty.start(
      shell,
      workingDirectory: workingDirectory,
      columns: cols,
      rows: rows,
      environment: Platform.environment,
    );

    _pid = _pty!.pid;

    // Create a Windows Job Object to track the process tree
    // This ensures all child processes are terminated when we kill the task
    _jobHandle = NativeBindings.instance.createJobForProcess(_pid!);

    terminal.write('\x1b[90mPID: $_pid\x1b[0m\r\n\r\n');

    // Forward PTY output to terminal and log buffer
    _outputSubscription = _pty!.output.listen(
      (data) {
        final decoded = utf8.decode(data, allowMalformed: true);
        terminal.write(decoded);

        // Only capture to log after command is sent (skip shell init)
        if (_logCaptureStarted) {
          _appendToLog(_stripAnsi(decoded));
        }

        // Feed output to step executor for pattern matching
        if (hasSteps && !stepsCompleted) {
          _processOutputForSteps(_stripAnsi(decoded));
        }
      },
      onDone: _cleanup,
    );

    // Wire terminal resize to PTY (rows, cols order)
    terminal.onResize = (w, h, pw, ph) {
      _pty?.resize(h, w);
    };

    // Listen for exit
    _pty!.exitCode.then((code) {
      _exitCode = code;
      // Flush any remaining buffered content
      if (_logLineBuffer.isNotEmpty) {
        _logBuffer.add(_logLineBuffer);
        _logLineBuffer = '';
      }
      _cleanup();
      onExit?.call();
    });

    // Send command after shell initializes
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_pty != null) {
        // Start log capture and add prompt line
        _logCaptureStarted = true;
        final promptPath = workingDirectory ?? Directory.current.path;
        _logBuffer.add('$promptPath> $fullCommand');

        // Send command with \r\n for Windows cmd.exe
        _pty!.write(Uint8List.fromList(utf8.encode('$fullCommand\r\n')));

        // Start step execution if we have steps
        if (hasSteps) {
          _startStepExecution();
        }

        // Note: Resource monitoring is handled by the centralized ResourceMonitorExtension
      }
    });
  }

  /// Start the step execution process
  void _startStepExecution() {
    _currentStepIndex = 0;
    _outputBuffer = '';
    _stepStatus = StepExecutionStatus.waitingForPattern;
    _startStepTimeout();
    onStepProgress?.call();

    // Log step execution start
    terminal.write(
        '\r\n\x1b[90m[Steps] Starting automation (${steps.length} steps)\x1b[0m\r\n');
  }

  /// Process output for step pattern matching
  void _processOutputForSteps(String output) {
    if (stepsCompleted || _stepStatus != StepExecutionStatus.waitingForPattern) {
      return;
    }

    // Add to buffer (keep last 4KB for pattern matching)
    _outputBuffer += output;
    if (_outputBuffer.length > 4096) {
      _outputBuffer = _outputBuffer.substring(_outputBuffer.length - 4096);
    }

    final step = currentStep;
    if (step == null) return;

    // Try to match the pattern
    try {
      final regex = RegExp(step.expect, multiLine: true);
      if (regex.hasMatch(_outputBuffer)) {
        _onPatternMatched();
      }
    } catch (e) {
      // Invalid regex - try plain text match
      if (_outputBuffer.contains(step.expect)) {
        _onPatternMatched();
      }
    }
  }

  /// Called when current step's pattern is matched
  void _onPatternMatched() {
    _stepTimeoutTimer?.cancel();
    final step = currentStep;
    if (step == null) return;

    // Log match
    terminal.write(
        '\x1b[90m[Step ${_currentStepIndex + 1}/${steps.length}] Pattern matched: "${step.expect}"\x1b[0m\r\n');

    // Send command if present
    if (step.send != null && step.send!.isNotEmpty) {
      terminal.write(
          '\x1b[90m[Step ${_currentStepIndex + 1}/${steps.length}] Sending: ${step.send}\x1b[0m\r\n');

      // Small delay before sending to ensure terminal is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_pty != null) {
          _pty!.write(Uint8List.fromList(utf8.encode('${step.send}\r\n')));
        }
      });
    }

    // Move to next step
    _currentStepIndex++;
    _outputBuffer = '';

    if (stepsCompleted) {
      _stepStatus = StepExecutionStatus.completed;
      terminal.write(
          '\r\n\x1b[32m[Steps] All steps completed. Terminal is now interactive.\x1b[0m\r\n');
    } else {
      _stepStatus = StepExecutionStatus.waitingForPattern;
      _startStepTimeout();
    }

    onStepProgress?.call();
  }

  /// Start timeout timer for current step
  void _startStepTimeout() {
    _stepTimeoutTimer?.cancel();
    final step = currentStep;
    if (step == null) return;

    _stepTimeoutTimer = Timer(Duration(milliseconds: step.timeout), () {
      if (_stepStatus == StepExecutionStatus.waitingForPattern) {
        _stepStatus = StepExecutionStatus.timedOut;
        terminal.write(
            '\r\n\x1b[33m[Step ${_currentStepIndex + 1}/${steps.length}] Timeout waiting for: "${step.expect}"\x1b[0m\r\n');
        terminal.write(
            '\x1b[33m[Steps] Automation paused. Terminal is interactive.\x1b[0m\r\n');
        onStepProgress?.call();
      }
    });
  }

  /// Retry the current step (after timeout)
  void retryCurrentStep() {
    if (_stepStatus == StepExecutionStatus.timedOut) {
      _stepStatus = StepExecutionStatus.waitingForPattern;
      _outputBuffer = '';
      _startStepTimeout();
      terminal.write(
          '\x1b[90m[Steps] Retrying step ${_currentStepIndex + 1}...\x1b[0m\r\n');
      onStepProgress?.call();
    }
  }

  /// Skip the current step
  void skipCurrentStep() {
    _stepTimeoutTimer?.cancel();

    terminal.write(
        '\x1b[33m[Step ${_currentStepIndex + 1}/${steps.length}] Skipped\x1b[0m\r\n');

    _currentStepIndex++;
    _outputBuffer = '';

    if (stepsCompleted) {
      _stepStatus = StepExecutionStatus.completed;
      terminal.write(
          '\r\n\x1b[32m[Steps] All steps completed. Terminal is now interactive.\x1b[0m\r\n');
    } else {
      _stepStatus = StepExecutionStatus.waitingForPattern;
      _startStepTimeout();
    }

    onStepProgress?.call();
  }

  // === RESOURCE MONITORING ===

  /// Called by ResourceMonitorExtension to push stats to this task
  void updateStats(ProcessStats stats) {
    _statsHistory.add(stats);
    // Keep only last 30 entries (2.5 minutes of data at 5s intervals)
    if (_statsHistory.length > 30) {
      _statsHistory.removeAt(0);
    }
    _statsController.add(stats);
  }

  /// Clear stats history (called when task starts)
  void clearStats() {
    _statsHistory.clear();
  }

  /// Append text to log buffer, handling line breaks properly
  void _appendToLog(String text) {
    // Add to line buffer
    _logLineBuffer += text;

    // Process complete lines
    while (_logLineBuffer.contains('\n')) {
      final newlineIndex = _logLineBuffer.indexOf('\n');
      final line = _logLineBuffer.substring(0, newlineIndex);
      _logLineBuffer = _logLineBuffer.substring(newlineIndex + 1);

      // Add non-empty lines (skip excessive blank lines)
      if (line.trim().isNotEmpty || _logBuffer.isEmpty || _logBuffer.last.trim().isNotEmpty) {
        _logBuffer.add(line);
      }
    }
  }

  /// Send input to the PTY
  void write(String input) {
    _pty?.write(const Utf8Encoder().convert(input));
  }

  /// Send raw bytes to the PTY
  void writeBytes(List<int> bytes) {
    _pty?.write(Uint8List.fromList(bytes));
  }

  /// Resize the PTY
  void resize(int cols, int rows) {
    _pty?.resize(cols, rows);
  }

  /// Graceful stop (send Ctrl+C)
  void stop() {
    if (!isRunning) return;
    _pty?.write(Uint8List.fromList([0x03])); // Ctrl+C
  }

  /// Force kill the process and all child processes
  void kill() {
    if (!isRunning) return;

    // Kill the entire process tree by PID (walks all descendants)
    if (_pid != null && _pid != 0) {
      NativeBindings.instance.killProcessTree(_pid!);
    }

    // Also terminate the Job Object if available
    if (_jobHandle != null && _jobHandle != 0) {
      NativeBindings.instance.terminateJob(_jobHandle!);
    }

    // Then kill the PTY process itself as final fallback
    _pty?.kill();
    _cleanup();
  }

  void _cleanup() {
    _stepTimeoutTimer?.cancel();
    _outputSubscription?.cancel();
    _outputSubscription = null;
    _pty = null;
    _pid = null;
    _jobHandle = null;
  }

  /// Dispose resources
  void dispose() {
    kill();
    _statsController.close();
  }

  /// Create a task from a template
  factory Task.fromTemplate(Template template) {
    return Task(
      id: _generateId(),
      name: template.name,
      command: template.command,
      arguments: template.arguments,
      workingDirectory: template.workingDirectory,
      createdAt: DateTime.now(),
      templateId: template.id,
      steps: template.steps,
    );
  }

  /// Create a task from a template with placeholder values substituted
  factory Task.fromTemplateWithValues(
    Template template,
    Map<String, String> placeholderValues,
  ) {
    // Substitute placeholders in command and arguments
    final (command, arguments) = PlaceholderExtractor.substituteCommandAndArgs(
      template.command,
      template.arguments,
      placeholderValues,
    );

    // Substitute placeholders in step sends
    final steps = template.steps.map((step) {
      if (step.send == null) return step;
      return step.copyWith(
        send: PlaceholderExtractor.substitute(step.send!, placeholderValues),
      );
    }).toList();

    return Task(
      id: _generateId(),
      name: template.name,
      command: command,
      arguments: arguments,
      workingDirectory: template.workingDirectory,
      createdAt: DateTime.now(),
      templateId: template.id,
      steps: steps,
    );
  }

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }
}
