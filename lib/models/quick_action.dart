/// A quick action is a user-defined command that can be executed on a running task.
///
/// Manual only — a button that types its command into the task's terminal.
/// Anything time-driven is a scheduled job on marcha's own clock
/// (`ScheduledJob` / `SchedulerExtension`), not a quick action.
class QuickAction {
  final String id;
  final String name;
  final String command;
  final String emoji;

  const QuickAction({
    required this.id,
    required this.name,
    required this.command,
    required this.emoji,
  });

  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      command: json['command'] ?? '',
      emoji: json['emoji'] ?? '⚡',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'emoji': emoji,
      };

  QuickAction copyWith({
    String? id,
    String? name,
    String? command,
    String? emoji,
  }) {
    return QuickAction(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      emoji: emoji ?? this.emoji,
    );
  }

  /// Generate a unique ID for a new quick action
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }
}
