/// Status of a history entry
enum HistoryStatus {
  running,
  completed,
  stopped,
  error,
  archived,
}

/// A record of a task that was launched
class HistoryEntry {
  final String id;
  final String name;
  final String command;
  final List<String> arguments;
  final String? workingDirectory;
  final String? templateId;
  final String? taskId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final HistoryStatus status;
  final String emoji;

  const HistoryEntry({
    required this.id,
    required this.name,
    required this.command,
    this.arguments = const [],
    this.workingDirectory,
    this.templateId,
    this.taskId,
    required this.startedAt,
    this.endedAt,
    this.status = HistoryStatus.running,
    this.emoji = '',
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      command: json['command'] ?? '',
      arguments: List<String>.from(json['arguments'] ?? []),
      workingDirectory: json['workingDirectory'],
      templateId: json['templateId'],
      taskId: json['taskId'],
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'])
          : DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
      status: HistoryStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => HistoryStatus.stopped,
      ),
      emoji: json['emoji'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'command': command,
    'arguments': arguments,
    if (workingDirectory != null) 'workingDirectory': workingDirectory,
    if (templateId != null) 'templateId': templateId,
    if (taskId != null) 'taskId': taskId,
    'startedAt': startedAt.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    'status': status.name,
    'emoji': emoji,
  };

  HistoryEntry copyWith({
    String? id,
    String? name,
    String? command,
    List<String>? arguments,
    String? workingDirectory,
    String? templateId,
    String? taskId,
    DateTime? startedAt,
    DateTime? endedAt,
    HistoryStatus? status,
    String? emoji,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      arguments: arguments ?? this.arguments,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      templateId: templateId ?? this.templateId,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
    );
  }

  /// Duration of the task (or time since started if still running)
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

  bool get isRunning => status == HistoryStatus.running;
  bool get isArchived => status == HistoryStatus.archived;

  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }
}
