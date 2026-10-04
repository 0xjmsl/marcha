import 'dart:async';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/scheduled_job.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/log_viewer.dart';

/// Scheduled jobs: marcha's own clock, independent of terminal tasks.
/// One row per job — time to next fire, a toggle, "last fired" as a hint, and
/// a chevron that opens the job's run history. Picking a run shows its
/// terminal output in a log pane on the right.
class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  Timer? _refresh;
  Timer? _liveRefresh;
  final Set<String> _expanded = {};
  String? _selectedRunId;

  @override
  void initState() {
    super.initState();
    core.addListener(_onCoreChanged);
    // Countdowns are relative to now — repaint them on the scheduler's cadence.
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _onCoreChanged());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _liveRefresh?.cancel();
    core.removeListener(_onCoreChanged);
    super.dispose();
  }

  void _onCoreChanged() {
    if (mounted) setState(() {});
  }

  /// While the selected run is still going, repaint every second so its
  /// output streams into the log pane.
  void _syncLiveRefresh() {
    final run = _selectedRunId != null ? core.scheduler.runById(_selectedRunId!) : null;
    final live = run != null && !run.isFinished;
    if (live && _liveRefresh == null) {
      _liveRefresh = Timer.periodic(const Duration(seconds: 1), (_) => _onCoreChanged());
    } else if (!live && _liveRefresh != null) {
      _liveRefresh!.cancel();
      _liveRefresh = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTheme.of(context);
    final colors = AppColorsExtension.of(context);
    final jobs = core.scheduler.all;
    final selectedRun = _selectedRunId != null ? core.scheduler.runById(_selectedRunId!) : null;
    if (_selectedRunId != null && selectedRun == null) _selectedRunId = null;
    _syncLiveRefresh();

    final list = jobs.isEmpty
        ? Center(
            child: Text('No scheduled jobs',
                style: TextStyle(fontSize: 13, color: colors.textMuted)),
          )
        : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _buildJob(jobs[i], colors),
          );

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildHeader(styles, colors),
          Expanded(
            child: selectedRun == null
                ? Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: list,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 560, child: list),
                      VerticalDivider(width: 1, color: colors.border),
                      Expanded(child: _buildLogPane(selectedRun)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPane(ScheduleRun run) {
    final job = core.scheduler.getById(run.jobId);
    final name = job?.name ?? run.jobId;
    return LogViewer(
      title: '$name · ${_formatStamp(run.firedAt)} (${run.trigger})',
      load: () => core.scheduler.logFor(run.id),
      exportName: name,
      onClose: () => setState(() => _selectedRunId = null),
    );
  }

  Widget _buildHeader(AppTextStyles styles, AppColorScheme colors) {
    return Container(
      height: 36 * styles.scale,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('Scheduled', style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _edit(null),
            icon: Icon(Icons.add, size: 16, color: AppColors.accent),
            label: Text('New', style: TextStyle(fontSize: 12, color: AppColors.accent)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJob(ScheduledJob job, AppColorScheme colors) {
    final expanded = _expanded.contains(job.id);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildRow(job, colors, expanded),
          if (expanded) _buildRuns(job, colors),
        ],
      ),
    );
  }

  Widget _buildRow(ScheduledJob job, AppColorScheme colors, bool expanded) {
    final running = core.scheduler.isRunning(job.id);
    final Color dot;
    if (running) {
      dot = AppColors.running;
    } else if (!job.enabled) {
      dot = colors.textMuted;
    } else if (job.lastExitCode != null && job.lastExitCode != 0) {
      dot = AppColors.error;
    } else {
      dot = AppColors.info;
    }

    final String status;
    if (running) {
      status = 'running…';
    } else if (!job.enabled) {
      status = 'off';
    } else {
      status = 'in ${_formatIn(job.nextDue.difference(DateTime.now()))}';
    }

    return Tooltip(
      message: _lastFiredHint(job),
      waitDuration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            _statusDot(dot),
            const SizedBox(width: 12),
            Text(job.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.name,
                      style: TextStyle(fontSize: 13, color: colors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(job.scheduleDescription,
                      style: TextStyle(fontSize: 11, color: colors.textMuted)),
                ],
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Consolas',
                color: job.enabled ? colors.textSecondary : colors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            _iconButton(
              tooltip: 'Run now',
              icon: Icons.play_arrow,
              size: 16,
              color: running ? colors.textMuted : colors.textSecondary,
              onPressed: running ? null : () => _runNow(job),
            ),
            _iconButton(
              tooltip: 'Edit',
              icon: Icons.edit,
              size: 14,
              color: colors.textSecondary,
              onPressed: () => _edit(job),
            ),
            SizedBox(
              height: 28,
              child: Switch(
                value: job.enabled,
                activeColor: AppColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => core.scheduler.setEnabled(job.id, v),
              ),
            ),
            _iconButton(
              tooltip: expanded ? 'Hide runs' : 'Show runs',
              icon: expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: colors.textSecondary,
              onPressed: () => setState(() {
                if (!_expanded.remove(job.id)) _expanded.add(job.id);
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Run now, and open the new run straight away so its output streams in.
  void _runNow(ScheduledJob job) {
    if (!core.scheduler.runNow(job.id)) return;
    final runs = core.scheduler.runsFor(job.id);
    setState(() {
      _expanded.add(job.id);
      if (runs.isNotEmpty) _selectedRunId = runs.first.id;
    });
  }

  Widget _buildRuns(ScheduledJob job, AppColorScheme colors) {
    final runs = core.scheduler.runsFor(job.id);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.border))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: runs.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('No runs yet', style: TextStyle(fontSize: 12, color: colors.textMuted)),
            )
          : Column(children: runs.map((r) => _buildRun(r, colors)).toList()),
    );
  }

  Widget _buildRun(ScheduleRun run, AppColorScheme colors) {
    final selected = run.id == _selectedRunId;
    final Color dot;
    final String result;
    if (!run.isFinished) {
      dot = AppColors.running;
      result = 'running…';
    } else if (run.succeeded) {
      dot = AppColors.info;
      result = 'exit 0';
    } else {
      dot = AppColors.error;
      result = 'exit ${run.exitCode}';
    }
    final duration = _formatIn((run.finishedAt ?? DateTime.now()).difference(run.firedAt));
    final mono = TextStyle(fontSize: 12, fontFamily: 'Consolas', color: colors.textSecondary);

    return InkWell(
      onTap: () => setState(() => _selectedRunId = selected ? null : run.id),
      child: Container(
        color: selected ? colors.sidebarSelected : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            const SizedBox(width: 20),
            _statusDot(dot, size: 6),
            const SizedBox(width: 10),
            Text(_formatStamp(run.firedAt), style: mono),
            const SizedBox(width: 12),
            SizedBox(
              width: 70,
              child: Text(run.trigger, style: TextStyle(fontSize: 11, color: colors.textMuted)),
            ),
            const Spacer(),
            Text(duration, style: mono.copyWith(color: colors.textMuted)),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: Text(result,
                  textAlign: TextAlign.right,
                  style: mono.copyWith(color: run.isFinished && !run.succeeded ? AppColors.error : null)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 16, color: selected ? colors.textBright : colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(Color color, {double size = 8}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _iconButton({
    required String tooltip,
    required IconData icon,
    required double size,
    required Color color,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        tooltip: tooltip,
        icon: Icon(icon, size: size, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: onPressed,
      );

  String _lastFiredHint(ScheduledJob job) {
    final fired = job.lastFiredAt;
    if (fired == null) return 'Never fired';
    final parts = ['Last fired ${_formatStamp(fired)} (${job.lastTrigger ?? 'schedule'})'];
    final finished = job.lastFinishedAt;
    if (core.scheduler.isRunning(job.id)) {
      parts.add('still running');
    } else if (finished != null && !finished.isBefore(fired)) {
      parts.add('exit ${job.lastExitCode} after ${_formatIn(finished.difference(fired))}');
    }
    return parts.join('\n');
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatStamp(DateTime t) =>
      '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

  static String _formatIn(Duration d) {
    if (d.isNegative) return '0s';
    if (d.inHours >= 1) return '${d.inHours}h ${_two(d.inMinutes % 60)}m';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ${_two(d.inSeconds % 60)}s';
    return '${d.inSeconds}s';
  }

  Future<void> _edit(ScheduledJob? job) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _JobEditDialog(job: job),
    );
    if (mounted) setState(() {});
  }
}

class _JobEditDialog extends StatefulWidget {
  final ScheduledJob? job;
  const _JobEditDialog({this.job});

  @override
  State<_JobEditDialog> createState() => _JobEditDialogState();
}

class _JobEditDialogState extends State<_JobEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _command;
  late final TextEditingController _dir;
  late final TextEditingController _value;
  late JobScheduleType _type;
  String? _error;

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _name = TextEditingController(text: j?.name ?? '');
    _command = TextEditingController(text: j?.command ?? '');
    _dir = TextEditingController(text: j?.workingDirectory ?? '');
    _type = j?.scheduleType ?? JobScheduleType.daily;
    _value = TextEditingController(text: j?.scheduleValue ?? '03:00');
  }

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _dir.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final command = _command.text.trim();
    final value = _value.text.trim();
    if (name.isEmpty || command.isEmpty) {
      setState(() => _error = 'Name and command are required');
      return;
    }
    final valid = _type == JobScheduleType.daily
        ? ScheduledJob.parseClock(value) != null
        : (int.tryParse(value) ?? 0) >= 1;
    if (!valid) {
      setState(() => _error = _type == JobScheduleType.daily
          ? 'Time must be HH:MM (24h)'
          : 'Interval must be a whole number of minutes');
      return;
    }
    final dir = _dir.text.trim();
    final base = widget.job ??
        ScheduledJob(
          id: ScheduledJob.generateId(),
          name: name,
          command: command,
          scheduleType: _type,
          scheduleValue: value,
          armedAt: DateTime.now(),
        );
    await core.scheduler.upsert(base.copyWith(
      name: name,
      command: command,
      workingDirectory: dir.isEmpty ? null : dir,
      clearWorkingDirectory: dir.isEmpty,
      scheduleType: _type,
      scheduleValue: value,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await core.scheduler.delete(widget.job!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    return AlertDialog(
      title: Text(widget.job == null ? 'New scheduled job' : 'Edit scheduled job',
          style: TextStyle(fontSize: 15, color: colors.textPrimary)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(colors, 'Name', _name),
            _field(colors, 'Command', _command, mono: true),
            _field(colors, 'Working directory (optional)', _dir, mono: true),
            const SizedBox(height: 4),
            Row(
              children: [
                SegmentedButton<JobScheduleType>(
                  segments: const [
                    ButtonSegment(value: JobScheduleType.daily, label: Text('Daily at')),
                    ButtonSegment(value: JobScheduleType.interval, label: Text('Every (min)')),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _value.text = _type == JobScheduleType.daily ? '03:00' : '60';
                  }),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 90, child: _input(colors, _value, mono: true)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.job != null)
          TextButton(
            onPressed: _delete,
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _save,
          child: Text('Save', style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }

  Widget _field(AppColorScheme colors, String label, TextEditingController c, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          const SizedBox(height: 4),
          _input(colors, c, mono: mono),
        ],
      ),
    );
  }

  Widget _input(AppColorScheme colors, TextEditingController c, {bool mono = false}) {
    return TextField(
      controller: c,
      style: TextStyle(
        fontSize: 13,
        fontFamily: mono ? 'Consolas' : null,
        color: colors.textPrimary,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}
