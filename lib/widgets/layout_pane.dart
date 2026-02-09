import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/core.dart';
import '../core/templates_extension.dart';
import '../models/slot_assignment.dart';
import '../models/template.dart';
import '../models/task_group.dart';
import '../models/history_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../screens/template_edit_screen.dart';
import '../screens/task_group_edit_screen.dart';
import '../screens/resources_screen.dart';
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
    final sizes = core.settings.uiSizes;

    final header = Container(
      height: sizes.paneHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.paneHeaderButtonPadding * 2),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: sizes.paneHeaderDragIconSize, color: colors.textMuted.withValues(alpha: 0.5)),
          SizedBox(width: sizes.paneHeaderButtonPadding),
          Icon(icon, size: sizes.paneHeaderIconSize, color: iconColor ?? colors.textMuted),
          SizedBox(width: sizes.paneHeaderButtonPadding * 1.5),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: sizes.paneHeaderTitleFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (info != null) ...[Text(info!, style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.paneHeaderInfoFontSize)), SizedBox(width: sizes.paneHeaderButtonPadding * 2)],
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
    final sizes = core.settings.uiSizes;
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
                height: sizes.groupRowHeight,
                padding: EdgeInsets.symmetric(horizontal: sizes.groupRowHeight / 3.5),
                decoration: BoxDecoration(
                  color: colors.surfaceLight,
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Row(
                  children: [
                    Icon(_isExpanded ? Icons.expand_more : Icons.chevron_right, size: sizes.groupExpandIconSize, color: colors.textMuted),
                    SizedBox(width: sizes.groupRowHeight / 7),
                    Text(widget.group.emoji, style: TextStyle(fontSize: sizes.groupEmojiSize)),
                    SizedBox(width: sizes.groupRowHeight / 4.7),
                    Expanded(
                      child: Text(
                        widget.group.name.toUpperCase(),
                        style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: sizes.groupTitleFontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${templates.length}', style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.groupCountFontSize)),
                    if (_isHovered) ...[
                      SizedBox(width: sizes.groupRowHeight / 7),
                      GestureDetector(
                        onTap: _runAllTasks,
                        child: Tooltip(
                          message: 'Run All',
                          child: Padding(
                            padding: EdgeInsets.all(sizes.groupRowHeight / 14),
                            child: Icon(Icons.play_arrow, size: sizes.groupActionIconSize, color: AppColors.running),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (details) => _showContextMenu(details.globalPosition),
                        child: Padding(
                          padding: EdgeInsets.all(sizes.groupRowHeight / 14),
                          child: Icon(Icons.more_vert, size: sizes.groupActionIconSize, color: colors.textMuted),
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
    final sizes = core.settings.uiSizes;

    final content = Container(
      height: sizes.taskRowHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.taskRowHeight / 4.5),
      decoration: BoxDecoration(
        color: _isHovered ? colors.surfaceLighter : Colors.transparent,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Bullet indicator for grouped tasks
          if (widget.inGroup) ...[
            Container(
              width: sizes.taskBulletSize,
              height: sizes.taskBulletSize,
              margin: EdgeInsets.only(left: sizes.taskBulletSize * 0.67, right: sizes.taskBulletSize),
              decoration: BoxDecoration(color: colors.textMuted, shape: BoxShape.circle),
            ),
          ],
          Text(widget.template.emoji, style: TextStyle(fontSize: sizes.taskEmojiSize)),
          SizedBox(width: sizes.taskRowHeight / 4.5),
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
                        style: AppTheme.bodySmall.copyWith(color: colors.textPrimary, fontSize: sizes.taskNameFontSize),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.template.hasSteps) ...[SizedBox(width: sizes.taskBulletSize), _SteppedBadge()],
                  ],
                ),
                Text(
                  widget.template.displayCommand,
                  style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.taskCommandFontSize),
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
                  padding: EdgeInsets.all(sizes.taskRowHeight / 18),
                  child: Icon(Icons.play_arrow, size: sizes.taskActionIconSize, color: AppColors.running),
                ),
              ),
            ),
            SizedBox(width: sizes.taskRowHeight / 9),
            GestureDetector(
              onTapDown: (details) => _showContextMenu(details.globalPosition),
              child: Padding(
                padding: EdgeInsets.all(sizes.taskRowHeight / 18),
                child: Icon(Icons.more_vert, size: sizes.taskActionIconSize, color: colors.textMuted),
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
    final sizes = core.settings.uiSizes;

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
        height: sizes.historyRowHeight,
        padding: EdgeInsets.symmetric(horizontal: sizes.historyRowHeight / 5),
        decoration: BoxDecoration(
          color: _isHovered ? colors.surfaceLighter : Colors.transparent,
          border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Status dot
            Container(
              width: sizes.historyStatusDotSize,
              height: sizes.historyStatusDotSize,
              decoration: BoxDecoration(color: _statusColor(colors), shape: BoxShape.circle),
            ),
            SizedBox(width: sizes.historyStatusDotSize),
            if (widget.entry.emoji.isNotEmpty) ...[Text(widget.entry.emoji, style: TextStyle(fontSize: sizes.historyEmojiSize)), SizedBox(width: sizes.historyEmojiSize / 2)],
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
                          style: AppTheme.bodySmall.copyWith(color: colors.textPrimary, fontSize: sizes.historyNameFontSize),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hasSteps()) ...[SizedBox(width: sizes.historyEmojiSize / 2), _SteppedBadge()],
                    ],
                  ),
                  Flexible(
                    child: Row(
                      children: [
                        Text(_formatTime(widget.entry.startedAt), style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.historyTimeFontSize)),
                        Flexible(
                          child: Text(
                            ' · ${widget.entry.durationString}',
                            style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.historyTimeFontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (widget.entry.isRunning) ...[
              // Always-visible pane indicator for running tasks
              _PaneIndicator(
                taskId: widget.entry.taskId,
                onTap: _displayTask,
                iconSize: sizes.historyActionIconSize,
              ),
              if (_isHovered)
                _RowButton(icon: Icons.stop, color: AppColors.stopped, tooltip: 'Stop', onTap: _stopTask, iconSize: sizes.historyActionIconSize),
            ] else if (_isHovered) ...[
              _RowButton(icon: Icons.description, color: AppColors.info, tooltip: 'View Log', onTap: _viewLog, iconSize: sizes.historyActionIconSize),
              _RowButton(icon: Icons.delete, color: AppColors.error, tooltip: 'Delete', onTap: () => core.history.remove(widget.entry.id), iconSize: sizes.historyActionIconSize),
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
    final sizes = core.settings.uiSizes;

    return Container(
      color: theme.background,
      child: Column(
        children: [
          // Header matching terminal style - wrapped in draggable
          DraggablePaneHeader(
            slotIndex: widget.slotIndex,
            child: Container(
              height: sizes.logHeaderHeight,
              padding: EdgeInsets.symmetric(horizontal: sizes.logContentPadding),
              decoration: BoxDecoration(
                color: theme.background,
                border: Border(bottom: BorderSide(color: theme.borderColor, width: 1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.drag_indicator, size: sizes.logHeaderDragIconSize, color: theme.foreground.withValues(alpha: 0.3)),
                  SizedBox(width: sizes.logContentPadding / 2),
                  Icon(Icons.description, size: sizes.logHeaderIconSize, color: theme.foreground.withValues(alpha: 0.5)),
                  SizedBox(width: sizes.logContentPadding),
                  Expanded(
                    child: Text(
                      widget.entry != null ? '${widget.entry!.name} (Log)' : 'Log',
                      style: TextStyle(color: theme.foreground.withValues(alpha: 0.7), fontSize: sizes.logHeaderTitleFontSize, fontFamily: 'Consolas'),
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
                      padding: EdgeInsets.all(sizes.logContentPadding / 2),
                      child: Icon(Icons.download, size: sizes.logHeaderIconSize, color: theme.foreground.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                SizedBox(width: sizes.logContentPadding / 2),
                // Close button
                Tooltip(
                  message: 'Close',
                  child: InkWell(
                    onTap: () => core.layout.clearSlot(widget.slotIndex),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: EdgeInsets.all(sizes.logContentPadding / 2),
                      child: Icon(Icons.close, size: sizes.logHeaderIconSize, color: theme.foreground.withValues(alpha: 0.5)),
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
                            style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                          ),
                        );
                      }

                      return Padding(
                        padding: EdgeInsets.all(sizes.logContentPadding),
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              // Header info
                              TextSpan(
                                text: '--- Log for ${log.name} ---\n',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                              ),
                              TextSpan(
                                text: 'Command: ${log.command} ${log.arguments.join(' ')}\n',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                              ),
                              if (log.workingDirectory != null)
                                TextSpan(
                                  text: 'Directory: ${log.workingDirectory!.replaceAll('\\\\', '\\')}\n',
                                  style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                                ),
                              TextSpan(
                                text: 'Duration: ${log.durationString}',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                              ),
                              if (log.exitCode != null)
                                TextSpan(
                                  text: ' | Exit code: ${log.exitCode}',
                                  style: TextStyle(color: log.exitCode == 0 ? theme.successColor : theme.errorColor, fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                                ),
                              TextSpan(
                                text: '\n${'─' * 50}\n\n',
                                style: TextStyle(color: theme.foreground.withValues(alpha: 0.3), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                              ),
                              // Log content
                              TextSpan(
                                text: log.lines.join('\n').replaceAll('\\\\', '\\'),
                                style: TextStyle(color: theme.foreground, fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
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
                      style: TextStyle(color: theme.foreground.withValues(alpha: 0.5), fontFamily: 'Consolas', fontSize: sizes.logContentFontSize),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Resources pane - reuses ResourcesContent from resources_screen.dart
class _ResourcesPane extends StatelessWidget {
  final int slotIndex;

  const _ResourcesPane({required this.slotIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PaneHeader(
          slotIndex: slotIndex,
          icon: Icons.monitor_heart,
          title: 'Resources',
          iconColor: AppColors.info,
          actions: [
            _HeaderButton(
              icon: Icons.close,
              tooltip: 'Close',
              onTap: () => core.layout.clearSlot(slotIndex),
            ),
          ],
        ),
        const Expanded(
          child: ResourcesContent(),
        ),
      ],
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
    final sizes = core.settings.uiSizes;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.all(sizes.paneHeaderButtonPadding),
          child: Icon(icon, size: sizes.paneHeaderButtonIconSize, color: color ?? colors.textSecondary),
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
  final double? iconSize;

  const _RowButton({required this.icon, required this.color, required this.tooltip, required this.onTap, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final size = iconSize ?? 14.0;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: EdgeInsets.all(size / 3.5),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

/// Always-visible pane indicator for running tasks
/// Shows which pane (slot number) a task is displayed on, or a dim icon if not displayed
class _PaneIndicator extends StatelessWidget {
  final String? taskId;
  final VoidCallback onTap;
  final double iconSize;

  const _PaneIndicator({required this.taskId, required this.onTap, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final slotIndex = taskId != null ? core.layout.findSlotByTaskId(taskId!) : null;
    final isDisplayed = slotIndex != null;

    return Tooltip(
      message: isDisplayed ? 'Displayed on Pane ${slotIndex + 1}' : 'Display on pane',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: iconSize / 3, vertical: iconSize / 5),
          decoration: BoxDecoration(
            color: isDisplayed ? AppColors.running.withValues(alpha: 0.15) : colors.surfaceLighter,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDisplayed ? AppColors.running.withValues(alpha: 0.4) : colors.border,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal, size: iconSize * 0.85, color: isDisplayed ? AppColors.running : colors.textMuted),
              SizedBox(width: iconSize / 4),
              Text(
                isDisplayed ? 'P${slotIndex + 1}' : '—',
                style: TextStyle(
                  fontSize: iconSize * 0.7,
                  fontWeight: FontWeight.bold,
                  color: isDisplayed ? AppColors.running : colors.textMuted,
                  fontFamily: 'Consolas',
                ),
              ),
            ],
          ),
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
