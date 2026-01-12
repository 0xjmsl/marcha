/// A stored log of terminal output for a completed task
class TerminalLog {
  final String id; // matches historyEntry.id
  final String name;
  final String command;
  final List<String> arguments;
  final String? workingDirectory;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? exitCode;
  final List<String> lines; // captured output lines

  const TerminalLog({
    required this.id,
    required this.name,
    required this.command,
    this.arguments = const [],
    this.workingDirectory,
    required this.startedAt,
    this.endedAt,
    this.exitCode,
    this.lines = const [],
  });

  factory TerminalLog.fromJson(Map<String, dynamic> json) {
    return TerminalLog(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      command: json['command'] ?? '',
      arguments: List<String>.from(json['arguments'] ?? []),
      workingDirectory: json['workingDirectory'],
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      exitCode: json['exitCode'],
      lines: List<String>.from(json['lines'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'arguments': arguments,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        'startedAt': startedAt.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (exitCode != null) 'exitCode': exitCode,
        'lines': lines,
      };

  /// Get plain text content for export
  String get plainText {
    final buffer = StringBuffer();

    // Clean header (normalize backslashes from JSON escaping)
    final dir = workingDirectory?.replaceAll('\\\\', '\\');
    buffer.writeln('Command: $command ${arguments.join(' ')}');
    if (dir != null) {
      buffer.writeln('Directory: $dir');
    }
    buffer.writeln('Duration: $durationString');
    if (exitCode != null) {
      buffer.writeln('Exit code: $exitCode');
    }
    buffer.writeln('─' * 50);
    buffer.writeln();

    // Log content (lines are now properly separated, normalize backslashes)
    buffer.write(lines.join('\n').replaceAll('\\\\', '\\'));

    return buffer.toString();
  }

  /// Duration of the task
  Duration get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  String get durationString {
    final d = duration;
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    } else {
      return '${d.inSeconds}s';
    }
  }
}
