import 'package:flutter_test/flutter_test.dart';
import 'package:marcha/models/scheduled_job.dart';

ScheduledJob daily(String at, {required DateTime armedAt, DateTime? lastFiredAt}) =>
    ScheduledJob(
      id: 't',
      name: 't',
      command: 'echo',
      scheduleType: JobScheduleType.daily,
      scheduleValue: at,
      armedAt: armedAt,
      lastFiredAt: lastFiredAt,
    );

void main() {
  test('daily: next occurrence after the anchor, same day or next', () {
    final job = daily('03:00', armedAt: DateTime(2026, 9, 28, 1, 0));
    expect(job.nextDue, DateTime(2026, 9, 28, 3, 0));

    final afterFire = daily('03:00',
        armedAt: DateTime(2026, 9, 1), lastFiredAt: DateTime(2026, 9, 28, 3, 0, 5));
    expect(afterFire.nextDue, DateTime(2026, 9, 29, 3, 0));
  });

  test('catch-up: several missed nights collapse into one due run', () {
    final now = DateTime(2026, 9, 28, 9, 30);
    final job = daily('03:00',
        armedAt: DateTime(2026, 7, 31), lastFiredAt: DateTime(2026, 8, 16, 19, 34));
    // Overdue since 08-17 03:00 — due now, once.
    expect(job.nextDue.isAfter(now), isFalse);
    // After that one run, the next due is tomorrow — no replay of every missed night.
    final fired = job.copyWith(lastFiredAt: now);
    expect(fired.nextDue, DateTime(2026, 9, 29, 3, 0));
  });

  test('re-arm: occurrences before armedAt never count as missed', () {
    final job = daily('03:00',
        armedAt: DateTime(2026, 9, 28, 9, 30), lastFiredAt: DateTime(2026, 8, 16, 19, 34));
    expect(job.nextDue, DateTime(2026, 9, 29, 3, 0));
  });

  test('interval: anchor + N minutes', () {
    final job = ScheduledJob(
      id: 't',
      name: 't',
      command: 'echo',
      scheduleType: JobScheduleType.interval,
      scheduleValue: '15',
      armedAt: DateTime(2026, 9, 28, 10, 0),
    );
    expect(job.nextDue, DateTime(2026, 9, 28, 10, 15));
  });

  test('parseClock rejects malformed times', () {
    expect(ScheduledJob.parseClock('03:00'), (3, 0));
    expect(ScheduledJob.parseClock('24:00'), isNull);
    expect(ScheduledJob.parseClock('3'), isNull);
  });
}
