import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../core/templates_extension.dart';
import '../models/slot_assignment.dart';
import '../models/template.dart';
import '../models/task.dart';
import '../models/task_group.dart';
import '../models/history_entry.dart';
import '../models/process_stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../screens/template_edit_screen.dart';
import '../screens/task_group_edit_screen.dart';
import 'pane_drag_overlay.dart';
import 'pane_target_selector.dart';
import 'placeholder_input_dialog.dart';
import 'terminal_view.dart';

/// Generic pane that renders based on SlotContentType
class LayoutPane extends StatefulWidget {
  final int slotIndex;

  const LayoutPane({super.key, required this.slotIndex});

  @override
  State<LayoutPane> createState() => _LayoutPaneState();
}

class _LayoutPaneState extends State<LayoutPane> {
  final GlobalKey _paneKey = GlobalKey();
  final _dragController = PaneDragController.instance;

  @override
  void initState() {
    super.initState();
    _dragController.registerPane(widget.slotIndex, _paneKey);
  }

  @override
  void dispose() {
    _dragController.unregisterPane(widget.slotIndex);
    super.dispose();
  }

  @override
  void didUpdateWidget(LayoutPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slotIndex != widget.slotIndex) {
      _dragController.unregisterPane(oldWidget.slotIndex);
      _dragController.registerPane(widget.slotIndex, _paneKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([core, _dragController]),
      builder: (context, _) {
        final slot = core.layout.getSlot(widget.slotIndex);
        if (slot == null) return const SizedBox.shrink();

        // Check if this pane should be highlighted (its task is being hovered in history)
        final isHighlighted = slot.isTerminal && slot.contentId != null && core.layout.hoveredTaskId == slot.contentId;

        // Get animated offset for this pane during drag
        final offset = _dragController.getAnimatedOffset(widget.slotIndex);
        final isAnimating = offset != Offset.zero;

        final paneContent = Container(
          key: _paneKey,
          decoration: BoxDecoration(
            color: colors.background,
            border: isHighlighted
                ? Border.all(color: const Color.fromARGB(255, 124, 212, 138), width: 1)
                : null,
            boxShadow: isAnimating
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: switch (slot.contentType) {
            SlotContentType.empty => _EmptyPane(slotIndex: widget.slotIndex),
            SlotContentType.tasksList => _TasksListPane(slotIndex: widget.slotIndex),
            SlotContentType.history => _HistoryPane(slotIndex: widget.slotIndex),
            SlotContentType.terminal => _TerminalPane(slotIndex: widget.slotIndex, taskId: slot.contentId),
            SlotContentType.resources => _ResourcesPane(slotIndex: widget.slotIndex),
          },
        );

        // Apply offset directly - animation happens via controller updates during drag
        if (offset == Offset.zero) {
          return paneContent;
        }

        return Transform.translate(
          offset: offset,
          child: paneContent,
        );
      },
    );
  }
}

/// Header for all pane types - now draggable for swapping panes
class _PaneHeader extends StatelessWidget {
  final int slotIndex;
  final IconData icon;
  final String title;
  final Color? iconColor;
  final String? info;
  final List<Widget>? actions;

  const _PaneHeader({
    required this.slotIndex,
    required this.icon,
    required this.title,
    this.iconColor,
    this.info,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    final header = Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 12, color: colors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: iconColor ?? colors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (info != null) ...[Text(info!, style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 10)), const SizedBox(width: 8)],
          if (actions != null) ...actions!,
        ],
      ),
    );

    return DraggablePaneHeader(
      slotIndex: slotIndex,
      child: header,
    );
  }
}

/// Empty pane placeholder
class _EmptyPane extends StatelessWidget {
  final int slotIndex;

  const _EmptyPane({required this.slotIndex});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Column(
      children: [
        _PaneHeader(slotIndex: slotIndex, icon: Icons.dashboard, title: 'Slot ${slotIndex + 1}'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 32, color: colors.textMuted),
                const SizedBox(height: 8),
                Text('Empty Slot', style: AppTheme.bodySmall.copyWith(color: colors.textMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tasks list pane (My Tasks)
class _TasksListPane extends StatelessWidget {
  final int slotIndex;

  const _TasksListPane({required this.slotIndex});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final displayOrder = core.templates.displayOrder;
    final totalCount = core.templates.all.length;

    return Column(
      children: [
        _PaneHeader(
          slotIndex: slotIndex,
          icon: Icons.folder_special,
          title: 'My Tasks',
          iconColor: AppColors.info,
          info: '$totalCount',
          actions: [
            _HeaderButton(icon: Icons.create_new_folder, tooltip: 'Add Group', color: colors.textSecondary, onTap: () => TaskGroupEditScreen.show(context)),
            _HeaderButton(icon: Icons.add, tooltip: 'Add Task', color: AppColors.info, onTap: () => TemplateEditScreen.show(context)),
          ],
        ),
        Expanded(
          child: displayOrder.isEmpty
              ? Center(
                  child: Text('No tasks configured', style: AppTheme.bodySmall.copyWith(color: colors.textMuted)),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: displayOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    core.templates.reorderDisplay(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final item = displayOrder[index];
                    if (item.type == DisplayItemType.group) {
                      final group = core.templates.getGroupById(item.id);
                      if (group == null) {
                        return SizedBox.shrink(key: ValueKey('missing_group_${item.id}'));
                      }
                      return _GroupRow(key: ValueKey('group_${item.id}'), group: group, index: index);
                    } else {
                      final template = core.templates.getById(item.id);
                      if (template == null) {
                        return SizedBox.shrink(key: ValueKey('missing_template_${item.id}'));
                      }
                      return _TemplateRow(key: ValueKey('template_${item.id}'), template: template, index: index);
                    }
                  },
                ),
        ),
      ],
    );
  }
}

/// Group row with expandable tasks
class _GroupRow extends StatefulWidget {
  final TaskGroup group;
  final int index;

  const _GroupRow({super.key, required this.group, required this.index});

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  bool _isExpanded = true;
  bool _isHovered = false;

  void _showContextMenu(Offset position) {
    final colors = AppColorsExtension.of(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      items: [
        _buildMenuItem('run_all', Icons.play_arrow, 'Run All', AppColors.running),
        _buildMenuItem('edit', Icons.edit, 'Edit', colors.textPrimary),
        const PopupMenuDivider(),
        _buildMenuItem('delete', Icons.delete, 'Delete Group', AppColors.error),
      ],
    ).then((value) async {
      if (value == null || !mounted) return;
      switch (value) {
        case 'run_all':
          _runAllTasks();
        case 'edit':
          if (mounted) await TaskGroupEditScreen.show(context, group: widget.group);
        case 'delete':
          await core.templates.removeGroup(widget.group.id);
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Future<void> _runAllTasks() async {
    final templates = widget.group.getOrderedTemplates(core.templates.all);
    for (final template in templates) {
      if (!mounted) return;
      final targetSlot = await PaneTargetSelector.show(context, title: 'Select Pane for ${template.name}', subtitle: '${templates.indexOf(template) + 1} of ${templates.length}');
      if (targetSlot == null || !mounted) break; // User cancelled
      final task = await PlaceholderInputDialog.launchTemplate(context, template);
      if (task == null || !mounted) break; // User cancelled placeholder input
      core.layout.assignTerminal(targetSlot, task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final templates = widget.group.getOrderedTemplates(core.templates.all);

    return Column(
      children: [
        // Group header (entire header is draggable)
        ReorderableDragStartListener(
          index: widget.index,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: colors.surfaceLight,
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    Icon(_isExpanded ? Icons.expand_more : Icons.chevron_right, size: 16, color: colors.textMuted),
                    const SizedBox(width: 4),
                    Text(widget.group.emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.group.name.toUpperCase(),
                        style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${templates.length}', style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 10)),
                    if (_isHovered) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: _runAllTasks,
                        child: Tooltip(
                          message: 'Run All',
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.play_arrow, size: 14, color: AppColors.running),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (details) => _showContextMenu(details.globalPosition),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.more_vert, size: 14, color: colors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        // Tasks inside group
        if (_isExpanded)
          for (final template in templates) _TemplateRow(template: template, inGroup: true, groupId: widget.group.id),
      ],
    );
  }
}

/// Single template row
class _TemplateRow extends StatefulWidget {
  final Template template;
  final bool inGroup;
  final int? index; // Index for drag handle (null = no drag handle)
  final String? groupId; // Group ID if inside a group (for ungrouping)

  const _TemplateRow({super.key, required this.template, this.inGroup = false, this.index, this.groupId});

  @override
  State<_TemplateRow> createState() => _TemplateRowState();
}

class _TemplateRowState extends State<_TemplateRow> {
  bool _isHovered = false;

  Future<void> _launchTemplate() async {
    // Show pane selector
    final targetSlot = await PaneTargetSelector.show(context, title: 'Select Target Pane', subtitle: widget.template.name);

    if (targetSlot == null || !mounted) return;

    // Launch task and assign to slot (with placeholder prompt if needed)
    final task = await PlaceholderInputDialog.launchTemplate(context, widget.template);
    if (task == null) return; // User cancelled placeholder input
    core.layout.assignTerminal(targetSlot, task.id);
  }

  void _showContextMenu(Offset position) {
    final colors = AppColorsExtension.of(context);
    final isGrouped = widget.groupId != null;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      items: [
        _buildMenuItem('run', Icons.play_arrow, 'Run', AppColors.running, colors),
        _buildMenuItem('edit', Icons.edit, 'Edit', colors.textPrimary, colors),
        _buildMenuItem('duplicate', Icons.copy, 'Duplicate', colors.textPrimary, colors),
        if (isGrouped) ...[const PopupMenuDivider(), _buildMenuItem('ungroup', Icons.folder_off, 'Remove from Group', AppColors.warning, colors)],
        const PopupMenuDivider(),
        _buildMenuItem('delete', Icons.delete, 'Delete', AppColors.error, colors),
      ],
    ).then((value) async {
      if (value == null || !mounted) return;
      switch (value) {
        case 'run':
          _launchTemplate();
        case 'edit':
          if (mounted) await TemplateEditScreen.show(context, template: widget.template);
        case 'duplicate':
          await core.templates.duplicate(widget.template.id);
        case 'ungroup':
          await core.templates.removeFromGroup(widget.template.id, widget.groupId!);
        case 'delete':
          await core.templates.remove(widget.template.id);
      }
    });
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String label, Color color, AppColorScheme colors) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition), child: _buildRowContent()),
    );
  }

  Widget _buildRowContent() {
    final colors = AppColorsExtension.of(context);

    final content = Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _isHovered ? colors.surfaceLighter : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Bullet indicator for grouped tasks
          if (widget.inGroup) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: 4, right: 6),
              decoration: BoxDecoration(color: colors.textMuted, shape: BoxShape.circle),
            ),
          ],
          Text(widget.template.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.template.name,
                        style: AppTheme.bodySmall.copyWith(color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.template.hasSteps) ...[const SizedBox(width: 6), _SteppedBadge()],
                  ],
                ),
                Text(
                  widget.template.displayCommand,
                  style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isHovered) ...[
            GestureDetector(
              onTap: _launchTemplate,
              child: Tooltip(
                message: 'Run',
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.play_arrow, size: 16, color: AppColors.running),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTapDown: (details) => _showContextMenu(details.globalPosition),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.more_vert, size: 16, color: colors.textMuted),
              ),
            ),
          ],
        ],
      ),
    );

    // Wrap in drag listener for ungrouped templates
    if (widget.index != null) {
      return ReorderableDragStartListener(index: widget.index!, child: content);
    }
    return content;
  }
}

/// History pane
class _HistoryPane extends StatelessWidget {
  final int slotIndex;

  const _HistoryPane({required this.slotIndex});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final entries = core.history.all;
    final runningCount = entries.where((e) => e.isRunning).length;

    return Column(
      children: [
        _PaneHeader(
          slotIndex: slotIndex,
          icon: Icons.history,
          title: 'History',
          iconColor: AppColors.info,
          info: runningCount > 0 ? '$runningCount running' : null,
          actions: entries.isNotEmpty ? [_HeaderButton(icon: Icons.clear_all, tooltip: 'Clear completed', onTap: () => core.history.clearCompleted())] : null,
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text('No history', style: AppTheme.bodySmall.copyWith(color: colors.textMuted)),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) => _HistoryRow(entry: entries[index]),
                ),
        ),
      ],
    );
  }
}

/// Single history row
class _HistoryRow extends StatefulWidget {
  final HistoryEntry entry;

  const _HistoryRow({required this.entry});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _isHovered = false;

  bool _hasSteps() {
    if (widget.entry.templateId == null) return false;
    final template = core.templates.getById(widget.entry.templateId!);
    return template?.hasSteps ?? false;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return time;
    }

    final date = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '$date $time';
  }

  Color _statusColor(AppColorScheme colors) {
    return switch (widget.entry.status) {
      HistoryStatus.running => AppColors.running,
      HistoryStatus.completed => AppColors.info,
      HistoryStatus.stopped => colors.textMuted,
      HistoryStatus.error => AppColors.error,
      HistoryStatus.archived => colors.textMuted,
    };
  }

  void _stopTask() {
    if (widget.entry.taskId != null) {
      core.tasks.stop(widget.entry.taskId!);
    }
  }

  Future<void> _displayTask() async {
    if (widget.entry.taskId == null) return;

    // Show pane selector
    final targetSlot = await PaneTargetSelector.show(context, title: 'Select Pane', subtitle: widget.entry.name);

    if (targetSlot == null || !mounted) return;

    // Assign running task to slot
    core.layout.assignTerminal(targetSlot, widget.entry.taskId!);
  }

  Future<void> _viewLog() async {
    // Show pane selector for log view
    final targetSlot = await PaneTargetSelector.show(context, title: 'View Log', subtitle: widget.entry.name);

    if (targetSlot == null) return;

    // Assign log view to slot (using historyId with 'log_' prefix)
    core.layout.assignSlot(targetSlot, SlotContentType.terminal, 'log_${widget.entry.id}');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        // Notify layout of hovered task for pane highlight
        if (widget.entry.isRunning && widget.entry.taskId != null) {
          core.layout.setHoveredTaskId(widget.entry.taskId);
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        // Clear hovered task
        if (widget.entry.isRunning && widget.entry.taskId != null) {
          core.layout.setHoveredTaskId(null);
        }
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _isHovered ? colors.surfaceLighter : Colors.transparent,
          border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _statusColor(colors), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            if (widget.entry.emoji.isNotEmpty) ...[Text(widget.entry.emoji, style: const TextStyle(fontSize: 12)), const SizedBox(width: 6)],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.entry.name,
                          style: AppTheme.bodySmall.copyWith(color: colors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hasSteps()) ...[const SizedBox(width: 6), _SteppedBadge()],
                    ],
                  ),
                  Flexible(
                    child: Row(
                      children: [
                        Text(_formatTime(widget.entry.startedAt), style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 10)),
                        Flexible(
                          child: Text(
                            ' · ${widget.entry.durationString}',
                            style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isHovered) ...[
              if (widget.entry.isRunning) ...[
                // Green if task is visible on a pane, blue otherwise
                _RowButton(
                  icon: Icons.terminal,
                  color: widget.entry.taskId != null && core.layout.findSlotByTaskId(widget.entry.taskId!) != null ? AppColors.running : AppColors.info,
                  tooltip: 'Display',
                  onTap: _displayTask,
                ),
                _RowButton(icon: Icons.stop, color: AppColors.stopped, tooltip: 'Stop', onTap: _stopTask),
              ] else ...[
                _RowButton(icon: Icons.description, color: AppColors.info, tooltip: 'View Log', onTap: _viewLog),
                _RowButton(icon: Icons.delete, color: AppColors.error, tooltip: 'Delete', onTap: () => core.history.remove(widget.entry.id)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Terminal pane (running task or log view)
class _TerminalPane extends StatefulWidget {
  final int slotIndex;
  final String? taskId;

  const _TerminalPane({required this.slotIndex, this.taskId});

  @override
  State<_TerminalPane> createState() => _TerminalPaneState();
}

class _TerminalPaneState extends State<_TerminalPane> {
  @override
  void initState() {
    super.initState();
    _ensureTaskRunning();
  }

  @override
  void didUpdateWidget(_TerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _ensureTaskRunning();
    }
  }

  void _ensureTaskRunning() {
    if (widget.taskId == null) return;
    if (widget.taskId!.startsWith('log_')) return;

    final task = core.tasks.getById(widget.taskId!);
    if (task != null && !task.isRunning) {
      // Start task if not running
      core.tasks.run(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a log view
    final isLogView = widget.taskId?.startsWith('log_') ?? false;
    final actualId = isLogView ? widget.taskId!.substring(4) : widget.taskId;

    if (isLogView) {
      final entry = core.history.getById(actualId!);
      return _LogView(slotIndex: widget.slotIndex, entry: entry);
    }

    final task = widget.taskId != null ? core.tasks.getById(widget.taskId!) : null;

    // No task assigned
    if (task == null) {
      return _buildEmptyTerminal();
    }

    // Task exists - show terminal
    return TerminalView(task: task, slotIndex: widget.slotIndex, onClose: () => core.layout.clearSlot(widget.slotIndex));
  }

  Widget _buildEmptyTerminal() {
    final colors = AppColorsExtension.of(context);

    return Column(
      children: [
        _PaneHeader(
          slotIndex: widget.slotIndex,
          icon: Icons.terminal,
          title: 'Terminal',
          iconColor: colors.textMuted,
          actions: [_HeaderButton(icon: Icons.close, tooltip: 'Close', onTap: () => core.layout.clearSlot(widget.slotIndex))],
        ),
        Expanded(
          child: Container(
            color: colors.background,
            child: Center(
              child: Text('No task assigned', style: AppTheme.bodySmall.copyWith(color: colors.textMuted)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Log view for completed tasks
class _LogView extends StatefulWidget {
  final int slotIndex;
  final HistoryEntry? entry;

  const _LogView({required this.slotIndex, this.entry});

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exportLog() async {
    if (widget.entry == null) return;

    final log = await core.logs.get(widget.entry!.id);
    if (log == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No log data available'), duration: Duration(seconds: 2)));
      }
      return;
    }

    // Generate default filename
    final timestamp = DateTime.now();
    final dateStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
    final safeName = widget.entry!.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final defaultFileName = '${safeName}_$dateStr-$timeStr.log';

    // Open save file dialog
    final filePath = await FilePicker.platform.saveFile(dialogTitle: 'Export Log', fileName: defaultFileName, type: FileType.custom, allowedExtensions: ['log', 'txt']);

    if (filePath == null) return; // User cancelled

    final result = await core.logs.export(widget.entry!.id, filePath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result != null ? 'Log exported to $result' : 'Failed to export log'), duration: const Duration(seconds: 3)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = core.settings.terminalTheme;
    final scale = core.settings.textScale;

    return Container(
      color: theme.background,
      child: Column(
        children: [
          // Header matching terminal style - wrapped in draggable
          DraggablePaneHeader(
            slotIndex: widget.slotIndex,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.background,
                border: Border(bottom: BorderSide(color: theme.borderColor, width: 1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator, size: 12, color: theme.foreground.withValues(alpha: 0.3)),
                  const SizedBox(width: 4),
                  Icon(Icons.description, size: 14, color: theme.foreground.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.entry != null ? '${widget.entry!.name} (Log)' : 'Log',
                      style: TextStyle(color: theme.foreground.withValues(alpha: 0.7), fontSize: 12, fontFamily: 'Consolas'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Export button
                Tooltip(
                  message: 'Export log',
                  child: InkWell(
                    onTap: _exportLog,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.download, size: 14, color: theme.foreground.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Close button
                Tooltip(
                  message: 'Close',
                  child: InkWell(
                    onTap: () => core.layout.clearSlot(widget.slotIndex),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: theme.foreground.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
          // Log content
          Expanded(
            child: widget.entry != null
                ? FutureBuilder(
                    future: core.logs.get(widget.entry!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: theme.foreground.withValues(alpha: 0.5)));
                      }

                      final log = snapshot.data;
                      if (log == null) {
                        return Center(
                          child: Text(
                            'No log data available',
                            style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              // Header info
                              TextSpan(
                                text: '--- Log for ${log.name} ---\n',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                              ),
                              TextSpan(
                                text: 'Command: ${log.command} ${log.arguments.join(' ')}\n',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                              ),
                              if (log.workingDirectory != null)
                                TextSpan(
                                  text: 'Directory: ${log.workingDirectory!.replaceAll('\\\\', '\\')}\n',
                                  style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                                ),
                              TextSpan(
                                text: 'Duration: ${log.durationString}',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                              ),
                              if (log.exitCode != null)
                                TextSpan(
                                  text: ' | Exit code: ${log.exitCode}',
                                  style: TextStyle(color: log.exitCode == 0 ? theme.successColor : theme.errorColor, fontFamily: 'Consolas', fontSize: 14.0 * scale),
                                ),
                              TextSpan(
                                text: '\n${'─' * 50}\n\n',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.3), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                              ),
                              // Log content
                              TextSpan(
                                text: log.lines.join('\n').replaceAll('\\\\', '\\'),
                                style: TextStyle(color: theme.foreground, fontFamily: 'Consolas', fontSize: 14.0 * scale),
                              ),
                            ],
                          ),
                          scrollPhysics: const ClampingScrollPhysics(),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      'Log not found',
                      style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: 14.0 * scale),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Resources pane (resource monitor for running tasks)
class _ResourcesPane extends StatefulWidget {
  final int slotIndex;

  const _ResourcesPane({required this.slotIndex});

  @override
  State<_ResourcesPane> createState() => _ResourcesPaneState();
}

class _ResourcesPaneState extends State<_ResourcesPane> {
  Timer? _refreshTimer;

  // Sorting state
  String _sortColumn = 'name';
  bool _sortAscending = true;

  // Expanded tasks (task IDs)
  final Set<String> _expandedTasks = {};

  @override
  void initState() {
    super.initState();
    // Refresh UI every 2 seconds to update duration and stats
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded(String taskId) {
    setState(() {
      if (_expandedTasks.contains(taskId)) {
        _expandedTasks.remove(taskId);
      } else {
        _expandedTasks.add(taskId);
      }
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<Task> _getSortedTasks(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) {
      int compare;
      switch (_sortColumn) {
        case 'name':
          compare = a.name.compareTo(b.name);
        case 'pid':
          compare = (a.pid ?? 0).compareTo(b.pid ?? 0);
        case 'children':
          compare = (a.latestStats?.processCount ?? 0)
              .compareTo(b.latestStats?.processCount ?? 0);
        case 'cpu':
          compare = (a.latestStats?.cpuUsage ?? 0)
              .compareTo(b.latestStats?.cpuUsage ?? 0);
        case 'memory':
          compare = (a.latestStats?.memoryUsage ?? 0)
              .compareTo(b.latestStats?.memoryUsage ?? 0);
        case 'duration':
          compare = a.createdAt.compareTo(b.createdAt);
        default:
          compare = 0;
      }
      return _sortAscending ? compare : -compare;
    });
    return sorted;
  }

  Future<void> _confirmKill(Task task) async {
    final colors = AppColorsExtension.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Kill Task', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to kill "${task.name}"?\nThis will terminate the process and all child processes.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Kill'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      core.tasks.kill(task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Column(
      children: [
        _PaneHeader(
          slotIndex: widget.slotIndex,
          icon: Icons.monitor_heart,
          title: 'Resources',
          iconColor: AppColors.info,
          actions: [
            _HeaderButton(
              icon: Icons.close,
              tooltip: 'Close',
              onTap: () => core.layout.clearSlot(widget.slotIndex),
            ),
          ],
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: core,
            builder: (context, _) {
              final runningTasks = core.tasks.running;

              if (runningTasks.isEmpty) {
                return _buildEmptyState(colors);
              }

              return Column(
                children: [
                  _buildSummaryCards(colors, runningTasks),
                  Expanded(
                    child: _buildProcessTable(colors, runningTasks),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 48,
            color: colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No Running Tasks',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Launch a task to see resources',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AppColorScheme colors, List<Task> tasks) {
    // Aggregate stats
    int totalProcesses = 0;
    double totalCpu = 0;
    int totalMemory = 0;

    for (final task in tasks) {
      final stats = task.latestStats;
      if (stats != null) {
        totalProcesses += stats.processCount;
        totalCpu += stats.cpuUsage;
        totalMemory += stats.memoryUsage;
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          _ResourcesSummaryCard(
            icon: Icons.play_circle,
            label: 'Running',
            value: '${tasks.length}',
            color: AppColors.success,
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ResourcesSummaryCard(
            icon: Icons.memory,
            label: 'CPU',
            value: '${totalCpu.toStringAsFixed(1)}%',
            color: AppColors.info,
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ResourcesSummaryCard(
            icon: Icons.storage,
            label: 'Memory',
            value: '${(totalMemory / 1024).toStringAsFixed(1)} MB',
            color: AppColors.warning,
            colors: colors,
          ),
          const SizedBox(width: 8),
          _ResourcesSummaryCard(
            icon: Icons.account_tree,
            label: 'Procs',
            value: '$totalProcesses',
            color: colors.textSecondary,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessTable(AppColorScheme colors, List<Task> tasks) {
    final sortedTasks = _getSortedTasks(tasks);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Table header
          _buildTableHeader(colors),
          // Table rows with expandable children
          ...sortedTasks.expand((task) => [
                _buildTableRow(colors, task),
                if (_expandedTasks.contains(task.id))
                  _buildChildrenSection(colors, task),
              ]),
        ],
      ),
    );
  }

  Widget _buildTableHeader(AppColorScheme colors) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20), // Expand button space
          _ResourcesSortableHeader(
            label: 'Task',
            column: 'name',
            width: 100,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
          ),
          _ResourcesSortableHeader(
            label: 'PID',
            column: 'pid',
            width: 50,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
          ),
          _ResourcesSortableHeader(
            label: 'CPU',
            column: 'cpu',
            width: 60,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
          ),
          _ResourcesSortableHeader(
            label: 'Mem',
            column: 'memory',
            width: 70,
            currentSort: _sortColumn,
            ascending: _sortAscending,
            onSort: _onSort,
            colors: colors,
          ),
          const Spacer(),
          SizedBox(
            width: 40,
            child: Text(
              'Act',
              style: AppTheme.monoSmall.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(AppColorScheme colors, Task task) {
    // Get emoji from template if available
    String emoji = '';
    if (task.templateId != null) {
      final template = core.templates.getById(task.templateId!);
      emoji = template?.emoji ?? '';
    }

    final stats = task.latestStats;
    final isExpanded = _expandedTasks.contains(task.id);
    final hasChildren = (stats?.children.length ?? 0) > 1;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isExpanded ? colors.surfaceLight : null,
        border: Border(
            bottom: BorderSide(
                color: colors.border.withValues(alpha: isExpanded ? 1 : 0.5))),
      ),
      child: Row(
        children: [
          // Expand button
          SizedBox(
            width: 20,
            child: hasChildren
                ? IconButton(
                    icon: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 14,
                    ),
                    color: colors.textMuted,
                    tooltip: isExpanded ? 'Collapse' : 'Expand',
                    onPressed: () => _toggleExpanded(task.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
          // Task name with emoji
          SizedBox(
            width: 100,
            child: Row(
              children: [
                if (emoji.isNotEmpty) ...[
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(color: colors.textPrimary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // PID
          SizedBox(
            width: 50,
            child: Text(
              task.pid?.toString() ?? '-',
              style: AppTheme.monoSmall.copyWith(color: colors.textSecondary, fontSize: 10),
            ),
          ),
          // CPU
          SizedBox(
            width: 60,
            child: Text(
              stats?.cpuPercent ?? '-',
              style: AppTheme.monoSmall.copyWith(color: AppColors.info, fontSize: 10),
            ),
          ),
          // Memory
          SizedBox(
            width: 70,
            child: Text(
              stats?.memoryMB ?? '-',
              style: AppTheme.monoSmall.copyWith(color: AppColors.warning, fontSize: 10),
            ),
          ),
          const Spacer(),
          // Kill button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.stop_circle, size: 16),
              color: AppColors.error,
              tooltip: 'Kill task',
              onPressed: () => _confirmKill(task),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenSection(AppColorScheme colors, Task task) {
    final stats = task.latestStats;
    final children = stats?.children ?? [];

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        children: children.map((child) {
          final isRoot = child.pid == task.pid;
          return _buildChildRow(colors, child, isRoot);
        }).toList(),
      ),
    );
  }

  Widget _buildChildRow(AppColorScheme colors, ChildProcessStats child, bool isRoot) {
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 32, right: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          // Process name
          SizedBox(
            width: 88,
            child: Row(
              children: [
                if (isRoot) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'ROOT',
                      style: AppTheme.monoSmall.copyWith(
                        color: AppColors.info,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    child.name,
                    style: AppTheme.monoSmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // PID
          SizedBox(
            width: 50,
            child: Text(
              '${child.pid}',
              style: AppTheme.monoSmall.copyWith(
                color: colors.textMuted,
                fontSize: 9,
              ),
            ),
          ),
          // CPU
          SizedBox(
            width: 60,
            child: Text(
              child.cpuPercent,
              style: AppTheme.monoSmall.copyWith(
                color: AppColors.info.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
          ),
          // Memory
          SizedBox(
            width: 70,
            child: Text(
              child.memoryMB,
              style: AppTheme.monoSmall.copyWith(
                color: AppColors.warning.withValues(alpha: 0.7),
                fontSize: 9,
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Summary card for resources pane (compact version)
class _ResourcesSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final AppColorScheme colors;

  const _ResourcesSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTheme.monoSmall.copyWith(
                      color: colors.textMuted,
                      fontSize: 8,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sortable header for resources pane (compact version)
class _ResourcesSortableHeader extends StatelessWidget {
  final String label;
  final String column;
  final double width;
  final String currentSort;
  final bool ascending;
  final ValueChanged<String> onSort;
  final AppColorScheme colors;

  const _ResourcesSortableHeader({
    required this.label,
    required this.column,
    required this.width,
    required this.currentSort,
    required this.ascending,
    required this.onSort,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentSort == column;

    return InkWell(
      onTap: () => onSort(column),
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Text(
              label,
              style: AppTheme.monoSmall.copyWith(
                color: isActive ? colors.textPrimary : colors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: colors.textPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small header button
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color ?? colors.textSecondary),
        ),
      ),
    );
  }
}

/// Small row action button
class _RowButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _RowButton({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

/// Badge indicating a task has automation steps
class _SteppedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_mode, size: 9, color: AppColors.accent),
          const SizedBox(width: 2),
          Text(
            'auto',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.accent, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
