import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/slot_assignment.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Dialog to select which pane slot to use for a task
class PaneTargetSelector extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PaneTargetSelector({
    super.key,
    required this.title,
    this.subtitle,
  });

  /// Show the selector and return selected slot index, or null if cancelled
  static Future<int?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) async {
    final slots = core.layout.slots;

    // If only one pane, use it directly (no choice to make)
    if (slots.length == 1) {
      return slots.first.slotIndex;
    }

    // More than one pane - let user choose
    return showDialog<int>(
      context: context,
      builder: (context) => PaneTargetSelector(
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final slots = core.layout.slots;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.headingSmall.copyWith(color: colors.textBright)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: AppTheme.bodySmall.copyWith(color: colors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            // Slot list
            ...slots.map((slot) => _SlotOption(
              slot: slot,
              onTap: () => Navigator.pop(context, slot.slotIndex),
            )),
            // Cancel
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colors.border),
                ),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTheme.bodySmall.copyWith(color: colors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotOption extends StatefulWidget {
  final SlotAssignment slot;
  final VoidCallback onTap;

  const _SlotOption({
    required this.slot,
    required this.onTap,
  });

  @override
  State<_SlotOption> createState() => _SlotOptionState();
}

class _SlotOptionState extends State<_SlotOption> {
  bool _isHovered = false;

  String get _slotLabel {
    return switch (widget.slot.contentType) {
      SlotContentType.empty => 'Empty',
      SlotContentType.tasksList => 'My Tasks',
      SlotContentType.history => 'History',
      SlotContentType.terminal => _getTaskName(),
    };
  }

  String _getTaskName() {
    if (widget.slot.contentId == null) return 'Terminal';
    // Try active tasks first
    final task = core.tasks.getById(widget.slot.contentId!);
    if (task != null) return task.name;
    // Fall back to history (for completed/stopped tasks)
    final historyEntry = core.history.all
        .where((e) => e.taskId == widget.slot.contentId)
        .firstOrNull;
    return historyEntry?.name ?? 'Terminal';
  }

  IconData get _slotIcon {
    return switch (widget.slot.contentType) {
      SlotContentType.empty => Icons.add_circle_outline,
      SlotContentType.tasksList => Icons.folder_special,
      SlotContentType.history => Icons.history,
      SlotContentType.terminal => Icons.terminal,
    };
  }

  Color _slotColor(AppColorScheme colors) {
    return switch (widget.slot.contentType) {
      SlotContentType.empty => colors.textMuted,
      SlotContentType.tasksList => AppColors.info,
      SlotContentType.history => AppColors.info,
      SlotContentType.terminal => AppColors.running,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final slotColor = _slotColor(colors);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _isHovered ? colors.surfaceLighter : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: slotColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(_slotIcon, size: 14, color: slotColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Slot ${widget.slot.slotIndex + 1}',
                      style: AppTheme.bodySmall.copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      _slotLabel,
                      style: AppTheme.monoSmall.copyWith(
                        color: colors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.slot.isEmpty)
                Text(
                  'AVAILABLE',
                  style: AppTheme.monoSmall.copyWith(
                    color: AppColors.running,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
