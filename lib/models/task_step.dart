/// A single automation step for a task
/// Each step waits for a regex pattern in terminal output, then optionally sends a command
class TaskStep {
  final String id;
  final String expect; // Regex pattern to wait for in terminal output
  final String? send; // Command to send when pattern matches (optional)
  final int timeout; // Timeout in milliseconds (default 30000)

  const TaskStep({
    required this.id,
    required this.expect,
    this.send,
    this.timeout = 30000,
  });

  /// Create a new step with generated ID
  factory TaskStep.create({
    required String expect,
    String? send,
    int timeout = 30000,
  }) {
    return TaskStep(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      expect: expect,
      send: send,
      timeout: timeout,
    );
  }

  factory TaskStep.fromJson(Map<String, dynamic> json) {
    return TaskStep(
      id: json['id'] ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      expect: json['expect'] ?? '',
      send: json['send'],
      timeout: json['timeout'] ?? 30000,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'expect': expect,
        if (send != null) 'send': send,
        if (timeout != 30000) 'timeout': timeout,
      };

  TaskStep copyWith({
    String? id,
    String? expect,
    String? send,
    int? timeout,
    bool clearSend = false,
  }) {
    return TaskStep(
      id: id ?? this.id,
      expect: expect ?? this.expect,
      send: clearSend ? null : (send ?? this.send),
      timeout: timeout ?? this.timeout,
    );
  }

  /// Check if this step has any {{placeholder}} in the send command
  bool get hasPlaceholders =>
      send != null && RegExp(r'\{\{[^}]+\}\}').hasMatch(send!);

  /// Get all placeholder names from the send command
  List<String> get placeholderNames {
    if (send == null) return [];
    final matches = RegExp(r'\{\{([^}]+)\}\}').allMatches(send!);
    return matches.map((m) => m.group(1)!).toList();
  }

  /// Get the send command with placeholders replaced
  String? getSendWithValues(Map<String, String> values) {
    if (send == null) return null;
    String result = send!;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// Display description for UI
  String get displayDescription {
    if (send == null || send!.isEmpty) {
      return 'Wait for: $expect';
    }
    return 'Wait for "$expect" → Send: $send';
  }
}

/// Utility to extract all placeholders from command, arguments, and steps
class PlaceholderExtractor {
  static final _placeholderRegex = RegExp(r'\{\{([^}]+)\}\}');

  /// Extract all unique placeholder names from a template/task
  static Set<String> extractAll({
    required String command,
    required List<String> arguments,
    List<TaskStep>? steps,
  }) {
    final placeholders = <String>{};

    // From command
    for (final match in _placeholderRegex.allMatches(command)) {
      placeholders.add(match.group(1)!);
    }

    // From arguments
    for (final arg in arguments) {
      for (final match in _placeholderRegex.allMatches(arg)) {
        placeholders.add(match.group(1)!);
      }
    }

    // From step sends
    if (steps != null) {
      for (final step in steps) {
        if (step.send != null) {
          for (final match in _placeholderRegex.allMatches(step.send!)) {
            placeholders.add(match.group(1)!);
          }
        }
      }
    }

    return placeholders;
  }

  /// Replace all placeholders in a string with values
  static String substitute(String text, Map<String, String> values) {
    String result = text;
    for (final entry in values.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// Replace placeholders in command and arguments
  static (String, List<String>) substituteCommandAndArgs(
    String command,
    List<String> arguments,
    Map<String, String> values,
  ) {
    final newCommand = substitute(command, values);
    final newArgs = arguments.map((arg) => substitute(arg, values)).toList();
    return (newCommand, newArgs);
  }
}
