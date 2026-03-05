enum ScheduleType { clock, interval, oneShot }

/// A quick action is a user-defined command that can be executed on a running task
class QuickAction {
  final String id;
  final String name;
  final String command;
  final String emoji;
  final ScheduleType? scheduleType;
  final String? scheduleValue;
  final bool scheduleEnabled;

  const QuickAction({
    required this.id,
    required this.name,
    required this.command,
    required this.emoji,
    this.scheduleType,
    this.scheduleValue,
    this.scheduleEnabled = true,
  });

  bool get isScheduled => scheduleType != null && scheduleEnabled;

  /// Human-readable schedule description
  String get scheduleDescription {
    if (scheduleType == null) return 'Manual only';
    switch (scheduleType!) {
      case ScheduleType.clock:
        return 'Daily at ${scheduleValue ?? "?"}';
      case ScheduleType.interval:
        return 'Every ${scheduleValue ?? "?"} min';
      case ScheduleType.oneShot:
        final v = scheduleValue ?? '';
        return v.contains(':') ? 'Once at $v' : 'Once in ${v}m';
    }
  }

  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      command: json['command'] ?? '',
      emoji: json['emoji'] ?? '⚡',
      scheduleType: json['scheduleType'] != null
          ? ScheduleType.values.byName(json['scheduleType'] as String)
          : null,
      scheduleValue: json['scheduleValue'] as String?,
      scheduleEnabled: json['scheduleEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'emoji': emoji,
        if (scheduleType != null) 'scheduleType': scheduleType!.name,
        if (scheduleValue != null) 'scheduleValue': scheduleValue,
        if (!scheduleEnabled) 'scheduleEnabled': false,
      };

  QuickAction copyWith({
    String? id,
    String? name,
    String? command,
    String? emoji,
    ScheduleType? scheduleType,
    String? scheduleValue,
    bool? scheduleEnabled,
    bool clearSchedule = false,
  }) {
    return QuickAction(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      emoji: emoji ?? this.emoji,
      scheduleType: clearSchedule ? null : (scheduleType ?? this.scheduleType),
      scheduleValue:
          clearSchedule ? null : (scheduleValue ?? this.scheduleValue),
      scheduleEnabled: clearSchedule
          ? true
          : (scheduleEnabled ?? this.scheduleEnabled),
    );
  }

  /// Generate a unique ID for a new quick action
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  }
}
