enum JobScheduleType { daily, interval }

/// One run of a scheduled job. Its terminal output is a `TerminalLog` stored
/// under the same id in `%APPDATA%\Marcha\logs\` (so `GET /api/logs/:id` reads it).
class ScheduleRun {
  final String id;
  final String jobId;

  /// `schedule`, `catch-up` or `manual`.
  final String trigger;
  final DateTime firedAt;
  final DateTime? finishedAt;
  final int? exitCode;

  const ScheduleRun({
    required this.id,
    required this.jobId,
    required this.trigger,
    required this.firedAt,
    this.finishedAt,
    this.exitCode,
  });

  bool get isFinished => finishedAt != null;
  bool get succeeded => exitCode == 0;

  factory ScheduleRun.fromJson(Map<String, dynamic> json) => ScheduleRun(
        id: json['id'] as String,
        jobId: json['jobId'] as String,
        trigger: json['trigger'] as String? ?? 'schedule',
        firedAt: DateTime.parse(json['firedAt'] as String),
        finishedAt: json['finishedAt'] != null ? DateTime.parse(json['finishedAt'] as String) : null,
        exitCode: json['exitCode'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'jobId': jobId,
        'trigger': trigger,
        'firedAt': firedAt.toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
        if (exitCode != null) 'exitCode': exitCode,
      };

  ScheduleRun finish(DateTime at, int code) => ScheduleRun(
        id: id,
        jobId: jobId,
        trigger: trigger,
        firedAt: firedAt,
        finishedAt: at,
        exitCode: code,
      );
}

/// A scheduled job: a command marcha's own clock runs on a schedule.
///
/// Independent from terminal tasks — a job has no pane and no host task.
/// It runs headless in its own PTY (`cmd.exe /c <command>`), its output goes
/// to `%APPDATA%\Marcha\schedules\<id>.log`, and its outcome is recorded here.
class ScheduledJob {
  final String id;
  final String name;
  final String command;
  final String? workingDirectory;
  final String emoji;
  final JobScheduleType scheduleType;

  /// `HH:MM` for [JobScheduleType.daily], minutes for [JobScheduleType.interval].
  final String scheduleValue;
  final bool enabled;

  /// When the schedule was (re)armed: created, enabled, or its schedule edited.
  /// Occurrences before this never count as missed.
  final DateTime armedAt;

  final DateTime? lastFiredAt;
  final DateTime? lastFinishedAt;
  final int? lastExitCode;

  /// Why the last fire happened: `schedule`, `catch-up` or `manual`.
  final String? lastTrigger;

  const ScheduledJob({
    required this.id,
    required this.name,
    required this.command,
    this.workingDirectory,
    this.emoji = '⏰',
    required this.scheduleType,
    required this.scheduleValue,
    this.enabled = true,
    required this.armedAt,
    this.lastFiredAt,
    this.lastFinishedAt,
    this.lastExitCode,
    this.lastTrigger,
  });

  /// The instant occurrences are counted from: the later of armedAt / lastFiredAt.
  DateTime get anchor {
    final fired = lastFiredAt;
    if (fired == null || fired.isBefore(armedAt)) return armedAt;
    return fired;
  }

  /// First occurrence strictly after [anchor]. When it is in the past, the job
  /// is due — whether marcha was open at that time (a normal fire) or closed
  /// (a missed run, caught up once).
  DateTime get nextDue => _occurrenceAfter(anchor);

  DateTime _occurrenceAfter(DateTime from) {
    switch (scheduleType) {
      case JobScheduleType.daily:
        final (hour, minute) = parseClock(scheduleValue) ?? (0, 0);
        var target = DateTime(from.year, from.month, from.day, hour, minute);
        if (!target.isAfter(from)) {
          target = DateTime(from.year, from.month, from.day + 1, hour, minute);
        }
        return target;
      case JobScheduleType.interval:
        final minutes = int.tryParse(scheduleValue) ?? 60;
        return from.add(Duration(minutes: minutes < 1 ? 1 : minutes));
    }
  }

  /// Parse `HH:MM` → (hour, minute), null when malformed.
  static (int, int)? parseClock(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  String get scheduleDescription {
    switch (scheduleType) {
      case JobScheduleType.daily:
        return 'Daily at $scheduleValue';
      case JobScheduleType.interval:
        return 'Every $scheduleValue min';
    }
  }

  factory ScheduledJob.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] != null ? DateTime.tryParse(json[key] as String) : null;
    return ScheduledJob(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
      workingDirectory: json['workingDirectory'] as String?,
      emoji: json['emoji'] as String? ?? '⏰',
      scheduleType: JobScheduleType.values.byName(json['scheduleType'] as String? ?? 'daily'),
      scheduleValue: json['scheduleValue'] as String? ?? '03:00',
      enabled: json['enabled'] as bool? ?? true,
      armedAt: date('armedAt') ?? DateTime.now(),
      lastFiredAt: date('lastFiredAt'),
      lastFinishedAt: date('lastFinishedAt'),
      lastExitCode: json['lastExitCode'] as int?,
      lastTrigger: json['lastTrigger'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        if (workingDirectory != null) 'workingDirectory': workingDirectory,
        'emoji': emoji,
        'scheduleType': scheduleType.name,
        'scheduleValue': scheduleValue,
        'enabled': enabled,
        'armedAt': armedAt.toIso8601String(),
        if (lastFiredAt != null) 'lastFiredAt': lastFiredAt!.toIso8601String(),
        if (lastFinishedAt != null) 'lastFinishedAt': lastFinishedAt!.toIso8601String(),
        if (lastExitCode != null) 'lastExitCode': lastExitCode,
        if (lastTrigger != null) 'lastTrigger': lastTrigger,
      };

  ScheduledJob copyWith({
    String? name,
    String? command,
    String? workingDirectory,
    bool clearWorkingDirectory = false,
    String? emoji,
    JobScheduleType? scheduleType,
    String? scheduleValue,
    bool? enabled,
    DateTime? armedAt,
    DateTime? lastFiredAt,
    DateTime? lastFinishedAt,
    int? lastExitCode,
    String? lastTrigger,
  }) {
    return ScheduledJob(
      id: id,
      name: name ?? this.name,
      command: command ?? this.command,
      workingDirectory:
          clearWorkingDirectory ? null : (workingDirectory ?? this.workingDirectory),
      emoji: emoji ?? this.emoji,
      scheduleType: scheduleType ?? this.scheduleType,
      scheduleValue: scheduleValue ?? this.scheduleValue,
      enabled: enabled ?? this.enabled,
      armedAt: armedAt ?? this.armedAt,
      lastFiredAt: lastFiredAt ?? this.lastFiredAt,
      lastFinishedAt: lastFinishedAt ?? this.lastFinishedAt,
      lastExitCode: lastExitCode ?? this.lastExitCode,
      lastTrigger: lastTrigger ?? this.lastTrigger,
    );
  }

  static String generateId() => DateTime.now().millisecondsSinceEpoch.toRadixString(36);
}
