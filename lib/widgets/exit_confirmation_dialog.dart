import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Dialog shown when user tries to exit with running processes
class ExitConfirmationDialog extends StatelessWidget {
  final List<Task> runningTasks;

  const ExitConfirmationDialog({super.key, required this.runningTasks});

  /// Show the dialog and return true if user confirms exit
  static Future<bool> show(BuildContext context) async {
    final runningTasks = core.tasks.running;

    // No running tasks - allow exit without confirmation
    if (runningTasks.isEmpty) {
      return true;
    }

    final colors = AppColorsExtension.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 500),
          child: ExitConfirmationDialog(runningTasks: runningTasks),
        ),
      ),
    );

    return result ?? false;
  }

  String _formatDuration(DateTime startedAt) {
    final duration = DateTime.now().difference(startedAt);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final sizes = core.settings.uiSizes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Running Processes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Message
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'The following ${runningTasks.length == 1 ? 'process is' : 'processes are'} still running:',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
        ),
        // Running processes list
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: runningTasks.length,
            itemBuilder: (context, index) {
              final task = runningTasks[index];
              final template = task.templateId != null
                  ? core.templates.getById(task.templateId!)
                  : null;
              final emoji = template?.emoji ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    // Running status indicator
                    Container(
                      width: sizes.historyStatusDotSize,
                      height: sizes.historyStatusDotSize,
                      decoration: const BoxDecoration(
                        color: AppColors.running,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: sizes.historyStatusDotSize),
                    // Emoji
                    if (emoji.isNotEmpty) ...[
                      Text(emoji, style: TextStyle(fontSize: sizes.historyEmojiSize)),
                      SizedBox(width: sizes.historyEmojiSize / 2),
                    ],
                    // Task info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.name,
                            style: AppTheme.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontSize: sizes.historyNameFontSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                'PID: ${task.pid}',
                                style: AppTheme.monoSmall.copyWith(
                                  color: colors.textMuted,
                                  fontSize: sizes.historyTimeFontSize,
                                ),
                              ),
                              Text(
                                ' · ${_formatDuration(task.createdAt)}',
                                style: AppTheme.monoSmall.copyWith(
                                  color: colors.textMuted,
                                  fontSize: sizes.historyTimeFontSize,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Warning message
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            'Exiting will forcefully terminate all running processes.',
            style: TextStyle(
              fontSize: 12,
              color: colors.textMuted,
            ),
          ),
        ),
        // Actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.stopped,
                ),
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Stop All & Exit'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
