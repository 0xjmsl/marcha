import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/slot_assignment.dart';
import '../models/template.dart';
import '../models/history_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pane_target_selector.dart';
import 'placeholder_input_dialog.dart';

/// Dropdown showing minimized panes (My Tasks / History)
class MinimizedPanesDropdown extends StatelessWidget {
  const MinimizedPanesDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        final showTasks = core.layout.isTasksListMinimized;
        final showHistory = core.layout.isHistoryMinimized;

        if (!showTasks && !showHistory) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<void>(
          tooltip: 'Minimized Panels',
          offset: const Offset(0, 36),
          constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: colors.surfaceLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showTasks)
                  const Icon(Icons.folder_special, size: 14, color: AppColors.info),
                if (showTasks && showHistory)
                  const SizedBox(width: 4),
                if (showHistory)
                  const Icon(Icons.history, size: 14, color: AppColors.info),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 16, color: colors.textMuted),
              ],
            ),
          ),
          itemBuilder: (context) => _buildMenuItems(context, showTasks, showHistory),
        );
      },
    );
  }

  List<PopupMenuEntry<void>> _buildMenuItems(
    BuildContext context,
    bool showTasks,
    bool showHistory,
  ) {
    final colors = AppColorsExtension.of(context);
    final items = <PopupMenuEntry<void>>[];

    if (showTasks) {
      items.add(_buildSectionHeader('My Tasks', Icons.folder_special, colors));
      items.add(_buildMaximizeOption(context, SlotContentType.tasksList, 'Maximize My Tasks', colors));

      // Show templates
      final templates = core.templates.all;
      for (final template in templates.take(5)) {
        items.add(_MinimizedTemplateItem(template: template));
      }
      if (templates.length > 5) {
        items.add(PopupMenuItem<void>(
          enabled: false,
          height: 28,
          child: Text(
            '+${templates.length - 5} more...',
            style: AppTheme.monoSmall.copyWith(color: colors.textMuted),
          ),
        ));
      }
    }

    if (showTasks && showHistory) {
      items.add(const PopupMenuDivider());
    }

    if (showHistory) {
      items.add(_buildSectionHeader('History', Icons.history, colors));
      items.add(_buildMaximizeOption(context, SlotContentType.history, 'Maximize History', colors));

      // Show running entries
      final running = core.history.running;
      for (final entry in running.take(3)) {
        items.add(_MinimizedHistoryItem(entry: entry));
      }

      // Show recent non-running
      final recent = core.history.all.where((e) => !e.isRunning).take(2);
      for (final entry in recent) {
        items.add(_MinimizedHistoryItem(entry: entry));
      }

      if (core.history.all.length > 5) {
        items.add(PopupMenuItem<void>(
          enabled: false,
          height: 28,
          child: Text(
            '+${core.history.all.length - 5} more...',
            style: AppTheme.monoSmall.copyWith(color: colors.textMuted),
          ),
        ));
      }
    }

    return items;
  }

  PopupMenuEntry<void> _buildSectionHeader(String title, IconData icon, AppColorScheme colors) {
    return PopupMenuItem<void>(
      enabled: false,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.info),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: AppTheme.monoSmall.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<void> _buildMaximizeOption(
    BuildContext context,
    SlotContentType type,
    String label,
    AppColorScheme colors,
  ) {
    return PopupMenuItem<void>(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onTap: () async {
        // Small delay to let popup close first
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          final slot = await PaneTargetSelector.show(
            context,
            title: 'Maximize To',
            subtitle: label,
          );
          if (slot != null) {
            core.layout.assignSlot(slot, type);
          }
        }
      },
      child: Row(
        children: [
          Icon(Icons.open_in_full, size: 12, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Maximize',
            style: AppTheme.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Minimized template item in dropdown
class _MinimizedTemplateItem extends PopupMenuEntry<void> {
  final Template template;

  const _MinimizedTemplateItem({required this.template});

  @override
  double get height => 36;

  @override
  bool represents(void value) => false;

  @override
  State<_MinimizedTemplateItem> createState() => _MinimizedTemplateItemState();
}

class _MinimizedTemplateItemState extends State<_MinimizedTemplateItem> {
  bool _isHovered = false;

  Future<void> _launch() async {
    // Capture navigator context before popping (dropdown context will be invalid after pop)
    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    final template = widget.template;

    navigator.pop(); // Close dropdown first
    await Future.delayed(const Duration(milliseconds: 100));

    final slot = await PaneTargetSelector.show(
      rootContext,
      title: 'Launch To',
      subtitle: template.name,
    );

    if (slot != null) {
      final task = await PlaceholderInputDialog.launchTemplate(rootContext, template);
      if (task != null) {
        core.layout.assignTerminal(slot, task.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _launch,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _isHovered ? colors.surfaceLighter : Colors.transparent,
          child: Row(
            children: [
              Text(widget.template.emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.template.name,
                  style: AppTheme.bodySmall.copyWith(color: colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isHovered)
                Icon(Icons.play_arrow, size: 14, color: AppColors.running),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimized history item in dropdown
class _MinimizedHistoryItem extends PopupMenuEntry<void> {
  final HistoryEntry entry;

  const _MinimizedHistoryItem({required this.entry});

  @override
  double get height => 36;

  @override
  bool represents(void value) => false;

  @override
  State<_MinimizedHistoryItem> createState() => _MinimizedHistoryItemState();
}

class _MinimizedHistoryItemState extends State<_MinimizedHistoryItem> {
  bool _isHovered = false;

  Color _statusColor(AppColorScheme colors) {
    return switch (widget.entry.status) {
      HistoryStatus.running => AppColors.running,
      HistoryStatus.completed => AppColors.info,
      HistoryStatus.stopped => colors.textMuted,
      HistoryStatus.error => AppColors.error,
      HistoryStatus.archived => colors.textMuted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (widget.entry.isRunning && widget.entry.taskId != null) {
            // Focus running task
            final slot = core.layout.findSlotByTaskId(widget.entry.taskId!);
            if (slot == null) {
              // Task not visible, show in available slot
              _showInSlot();
            }
          } else {
            // View log
            _viewLog();
          }
        },
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: _isHovered ? colors.surfaceLighter : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor(colors),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.entry.emoji.isNotEmpty) ...[
                Text(widget.entry.emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  widget.entry.name,
                  style: AppTheme.bodySmall.copyWith(color: colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                widget.entry.durationString,
                style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showInSlot() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final slot = await PaneTargetSelector.show(
      context,
      title: 'Show In',
      subtitle: widget.entry.name,
    );

    if (slot != null && widget.entry.taskId != null) {
      core.layout.assignTerminal(slot, widget.entry.taskId!);
    }
  }

  Future<void> _viewLog() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    final slot = await PaneTargetSelector.show(
      context,
      title: 'View Log',
      subtitle: widget.entry.name,
    );

    if (slot != null) {
      core.layout.assignSlot(slot, SlotContentType.terminal, 'log_${widget.entry.id}');
    }
  }
}
