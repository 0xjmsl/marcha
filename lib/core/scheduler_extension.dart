import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import '../models/scheduled_job.dart';
import '../models/task.dart';
import '../models/terminal_log.dart';
import '../services/native_bindings.dart';
import 'core.dart';

/// Marcha's own clock. Runs scheduled jobs independently of terminal tasks.
///
/// One 30 s tick compares every enabled job's [ScheduledJob.nextDue] against
/// the wall clock. The same rule covers a normal fire and a run missed while
/// marcha was closed: after startup the first tick finds the overdue
/// occurrence and runs it once (trigger `catch-up`). Polling the wall clock,
/// not a long one-shot Timer, also keeps fires on time across sleep/resume.
///
/// Every run is a [ScheduleRun] (`schedule_runs.json`) whose terminal output
/// is saved through [LogsExtension] under the run's id — the same store and
/// viewer the Process Manager uses for task logs.
class SchedulerExtension {
  final Core _core;

  SchedulerExtension(this._core);

  static const String _fileName = 'schedules.json';
  static const String _runsFileName = 'schedule_runs.json';
  static const Duration _tickInterval = Duration(seconds: 30);

  /// Runs kept per job; older runs and their logs are pruned.
  static const int maxRunsPerJob = 30;

  String get _filePath => '${Core.dataDir}\\$_fileName';
  String get _runsFilePath => '${Core.dataDir}\\$_runsFileName';

  List<ScheduledJob> _jobs = [];
  List<ScheduleRun> _runs = [];
  final Map<String, _RunningJob> _running = {}; // by job id
  Timer? _ticker;

  List<ScheduledJob> get all => List.unmodifiable(_jobs);
  ScheduledJob? getById(String id) => _jobs.where((j) => j.id == id).firstOrNull;
  bool isRunning(String id) => _running.containsKey(id);

  /// A job's runs, newest first.
  List<ScheduleRun> runsFor(String jobId) =>
      _runs.where((r) => r.jobId == jobId).toList()..sort((a, b) => b.firedAt.compareTo(a.firedAt));

  ScheduleRun? runById(String runId) => _runs.where((r) => r.id == runId).firstOrNull;

  /// A run's output: the live buffer while it runs, the saved log after.
  Future<TerminalLog?> logFor(String runId) async {
    for (final running in _running.values) {
      if (running.run.id == runId) return running.snapshot();
    }
    return _core.logs.get(runId);
  }

  /// Load jobs + runs and start the clock. Call once from Core.initialize.
  Future<void> start() async {
    await load();
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
    _tick();
  }

  /// Stop the clock and kill any job still running (app exit).
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    for (final running in _running.values) {
      running.kill();
    }
  }

  void _tick() {
    final now = DateTime.now();
    for (final job in _jobs) {
      if (!job.enabled || _running.containsKey(job.id)) continue;
      final due = job.nextDue;
      if (due.isAfter(now)) continue;
      // Later than a couple of ticks = the occurrence was missed (marcha
      // closed, or the box asleep) and this is its one catch-up run.
      final late = now.difference(due) > _tickInterval * 2;
      _fire(job, late ? 'catch-up' : 'schedule');
    }
  }

  /// Run a job now, outside its schedule. No-op if it is already running.
  bool runNow(String id) {
    final job = getById(id);
    if (job == null || _running.containsKey(id)) return false;
    _fire(job, 'manual');
    return true;
  }

  void _fire(ScheduledJob job, String trigger) {
    final firedAt = DateTime.now();
    final run = ScheduleRun(
      id: 'sched_${job.id}_${firedAt.millisecondsSinceEpoch.toRadixString(36)}',
      jobId: job.id,
      trigger: trigger,
      firedAt: firedAt,
    );
    _runs.add(run);
    _replace(job.copyWith(lastFiredAt: firedAt, lastTrigger: trigger));
    _save();
    _saveRuns();

    final running = _RunningJob(job, run);
    try {
      final pty = Pty.start(
        'cmd.exe',
        // flutter_pty repeats the executable as argv[0] on the command line;
        // cmd tolerates the duplicate and still honours /c + the exit code.
        arguments: ['/c', job.command],
        workingDirectory: job.workingDirectory,
        // Must be the full environment: without it flutter_pty passes only
        // TERM/LANG/PATH/HOME/USER/LOGNAME, and anything needing SystemRoot
        // (PowerShell: "Loading managed Windows PowerShell failed 8009001d") dies.
        environment: Platform.environment,
        columns: 200,
        rows: 50,
      );
      running.attach(pty, NativeBindings.instance.createJobForProcess(pty.pid));
      _running[job.id] = running;
      pty.output.listen(
        (data) => running.append(Task.stripAnsi(utf8.decode(data, allowMalformed: true))),
        onError: (_) {},
      );
      pty.exitCode.then((code) => _onExit(job.id, code));
      debugPrint('SchedulerExtension: Fired ${job.name} ($trigger)');
    } catch (e) {
      running.append('[marcha] Failed to start: $e\n');
      _finish(running, -1);
    }
    _core.notify();
  }

  void _onExit(String jobId, int code) {
    final running = _running.remove(jobId);
    if (running == null) return;
    // The PTY reports the exit status unsigned; show it the way Windows does.
    _finish(running, code > 0x7FFFFFFF ? code - 0x100000000 : code);
  }

  /// Record the outcome: the run, its terminal log, and the job's last result.
  void _finish(_RunningJob running, int code) {
    final finishedAt = DateTime.now();
    final run = running.run.finish(finishedAt, code);
    final i = _runs.indexWhere((r) => r.id == run.id);
    if (i >= 0) _runs[i] = run;
    _core.logs.saveLog(running.snapshot(endedAt: finishedAt, exitCode: code));

    final job = getById(running.job.id);
    if (job != null) {
      _replace(job.copyWith(lastFinishedAt: finishedAt, lastExitCode: code));
      _save();
    }
    _pruneRuns(running.job.id);
    _saveRuns();
    _core.notify();
  }

  /// Keep the newest [maxRunsPerJob] runs of a job; delete the rest + their logs.
  void _pruneRuns(String jobId) {
    final runs = runsFor(jobId);
    if (runs.length <= maxRunsPerJob) return;
    for (final old in runs.skip(maxRunsPerJob)) {
      _runs.removeWhere((r) => r.id == old.id);
      _core.logs.delete(old.id);
    }
  }

  // === EDITING ===

  /// Insert or update a job. A changed schedule (or re-enable) re-arms it, so
  /// occurrences before the edit are never treated as missed.
  Future<ScheduledJob> upsert(ScheduledJob job) async {
    final existing = getById(job.id);
    var next = job;
    if (existing == null) {
      next = job.copyWith(armedAt: DateTime.now());
      _jobs.add(next);
    } else {
      final rearm = existing.scheduleType != job.scheduleType ||
          existing.scheduleValue != job.scheduleValue ||
          (!existing.enabled && job.enabled);
      next = job.copyWith(
        armedAt: rearm ? DateTime.now() : existing.armedAt,
        lastFiredAt: existing.lastFiredAt,
        lastFinishedAt: existing.lastFinishedAt,
        lastExitCode: existing.lastExitCode,
        lastTrigger: existing.lastTrigger,
      );
      _replace(next);
    }
    await _save();
    _core.notify();
    return next;
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final job = getById(id);
    if (job == null || job.enabled == enabled) return;
    await upsert(job.copyWith(enabled: enabled));
  }

  /// Delete a job with its run history and logs.
  Future<void> delete(String id) async {
    _running.remove(id)?.kill();
    for (final run in runsFor(id)) {
      await _core.logs.delete(run.id);
    }
    _runs.removeWhere((r) => r.jobId == id);
    _jobs.removeWhere((j) => j.id == id);
    await _save();
    await _saveRuns();
    _core.notify();
  }

  void _replace(ScheduledJob job) {
    final i = _jobs.indexWhere((j) => j.id == job.id);
    if (i >= 0) _jobs[i] = job;
  }

  // === PERSISTENCE ===

  Future<void> load() async {
    _jobs = (await _readList(_filePath)).map(ScheduledJob.fromJson).toList();
    _runs = (await _readList(_runsFilePath)).map(ScheduleRun.fromJson).toList();
    // A run left unfinished means marcha exited mid-run: close it out as killed.
    final now = DateTime.now();
    _runs = _runs.map((r) => r.isFinished ? r : r.finish(now, -1)).toList();
    debugPrint('SchedulerExtension: Loaded ${_jobs.length} jobs, ${_runs.length} runs');
  }

  Future<List<Map<String, dynamic>>> _readList(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return [];
      final list = json.decode(await file.readAsString()) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('SchedulerExtension: Error loading $path: $e');
      return [];
    }
  }

  Future<void> _save() => _writeList(_filePath, _jobs.map((j) => j.toJson()).toList());
  Future<void> _saveRuns() => _writeList(_runsFilePath, _runs.map((r) => r.toJson()).toList());

  /// Write to a temp file and rename over the original, so a failed write
  /// never leaves the file truncated. Writes are serialized so two saves in
  /// quick succession (fire, then an instant exit) never share a temp file.
  Future<void> _writeList(String path, List<Map<String, dynamic>> data) {
    final content = const JsonEncoder.withIndent('  ').convert(data);
    return _writes = _writes.then((_) async {
      try {
        final tmp = File('$path.tmp');
        await tmp.writeAsString(content);
        await tmp.rename(path);
      } catch (e) {
        debugPrint('SchedulerExtension: Error saving $path: $e');
      }
    });
  }

  Future<void> _writes = Future.value();
}

class _RunningJob {
  final ScheduledJob job;
  final ScheduleRun run;
  Pty? _pty;
  int _jobHandle = 0;
  final List<String> _lines = [];
  String _partial = '';

  _RunningJob(this.job, this.run);

  void attach(Pty pty, int jobHandle) {
    _pty = pty;
    _jobHandle = jobHandle;
  }

  /// Split output into lines the way Task's log buffer does.
  void append(String text) {
    _partial += text;
    while (_partial.contains('\n')) {
      final i = _partial.indexOf('\n');
      final line = _partial.substring(0, i).replaceAll('\r', '');
      _partial = _partial.substring(i + 1);
      if (line.trim().isNotEmpty || _lines.isEmpty || _lines.last.trim().isNotEmpty) {
        _lines.add(line);
      }
    }
  }

  List<String> get lines => [..._lines, if (_partial.trim().isNotEmpty) _partial.replaceAll('\r', '')];

  TerminalLog snapshot({DateTime? endedAt, int? exitCode}) => TerminalLog(
        id: run.id,
        name: job.name,
        command: job.command,
        workingDirectory: job.workingDirectory,
        startedAt: run.firedAt,
        endedAt: endedAt,
        exitCode: exitCode,
        lines: lines,
      );

  void kill() {
    if (!NativeBindings.instance.terminateJob(_jobHandle)) {
      _pty?.kill();
    }
  }
}
