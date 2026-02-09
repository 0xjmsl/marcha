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
import 'pane_target_selector.dart';
import 'placeholder_input_dialog.dart';

/// Dropdown showing minimized panes (My Tasks / History)
/// with full pane features matching the actual views.
class MinimizedPanesDropdown extends StatefulWidget {
  const MinimizedPanesDropdown({super.key});

  @override
  State<MinimizedPanesDropdown> createState() => _MinimizedPanesDropdownState();
}

class _MinimizedPanesDropdownState extends State<MinimizedPanesDropdown> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final overlay = Overlay.of(context);
    final parentCtx = context; // Stable context from main widget tree
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _DropdownOverlay(
        link: _layerLink,
        onClose: _closeDropdown,
        parentContext: parentCtx,
      ),
    );
    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        final showTasks = core.layout.isTasksListMinimized;
        final showHistory = core.layout.isHistoryMinimized;

        if (!showTasks && !showHistory) {
          if (_isOpen) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _closeDropdown());
          }
          return const SizedBox.shrink();
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            onTap: _toggleDropdown,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _isOpen ? colors.surfaceLighter : colors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _isOpen ? AppColors.info.withValues(alpha: 0.5) : colors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTasks) const Icon(Icons.folder_special, size: 14, color: AppColors.info),
                  if (showTasks && showHistory) const SizedBox(width: 4),
                  if (showHistory) const Icon(Icons.history, size: 14, color: AppColors.info),
                  const SizedBox(width: 4),
                  Icon(_isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 16, color: colors.textMuted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen stack with backdrop + positioned dropdown panel
class _DropdownOverlay extends StatelessWidget {
  final LayerLink link;
  final VoidCallback onClose;
  final BuildContext parentContext;

  const _DropdownOverlay({required this.link, required this.onClose, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxHeight = (screenSize.height * 0.7).clamp(300.0, 700.0);

    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 4),
          child: _DropdownPanel(maxHeight: maxHeight, onClose: onClose, parentContext: parentContext),
        ),
      ],
    );
  }
}

/// The dropdown panel with tasks and history sections
class _DropdownPanel extends StatelessWidget {
  final double maxHeight;
  final VoidCallback onClose;
  final BuildContext parentContext;

  const _DropdownPanel({required this.maxHeight, required this.onClose, required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Material(
      elevation: 8,
      color: colors.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: 360,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListenableBuilder(
          listenable: core,
          builder: (context, _) {
            final showTasks = core.layout.isTasksListMinimized;
            final showHistory = core.layout.isHistoryMinimized;

            if (!showTasks && !showHistory) {
              return const SizedBox.shrink();
            }

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTasks) _buildTasksSection(context),
                  if (showTasks && showHistory) Divider(height: 1, color: colors.border),
                  if (showHistory) _buildHistorySection(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTasksSection(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final displayOrder = core.templates.displayOrder;
    final totalCount = core.templates.all.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DropdownSectionHeader(
          icon: Icons.folder_special,
          title: 'My Tasks',
          iconColor: AppColors.info,
          info: '$totalCount',
          actions: [
            _SmallButton(
              icon: Icons.open_in_full,
              tooltip: 'Maximize',
              color: colors.textMuted,
              onTap: () => _maximize(SlotContentType.tasksList, 'My Tasks'),
            ),
            _SmallButton(icon: Icons.create_new_folder, tooltip: 'Add Group', color: colors.textSecondary, onTap: () => TaskGroupEditScreen.show(context)),
            _SmallButton(icon: Icons.add, tooltip: 'Add Task', color: AppColors.info, onTap: () => TemplateEditScreen.show(context)),
          ],
        ),
        if (displayOrder.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No tasks configured', style: AppTheme.bodySmall.copyWith(color: colors.textMuted)),
          )
        else
          for (final item in displayOrder)
            if (item.type == DisplayItemType.group) _buildGroupOrEmpty(item.id) else _buildTemplateOrEmpty(item.id),
      ],
    );
  }

  Widget _buildGroupOrEmpty(String groupId) {
    final group = core.templates.getGroupById(groupId);
    if (group == null) return const SizedBox.shrink();
    return _DropdownGroupRow(group: group, onClose: onClose, parentContext: parentContext);
  }

  Widget _buildTemplateOrEmpty(String templateId) {
    final template = core.templates.getById(templateId);
    if (template == null) return const SizedBox.shrink();
    return _DropdownTemplateRow(template: template, onClose: onClose, parentContext: parentContext);
  }

  Widget _buildHistorySection(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final entries = core.history.all;
    final runningCount = entries.where((e) => e.isRunning).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DropdownSectionHeader(
          icon: Icons.history,
          title: 'History',
          iconColor: AppColors.info,
          info: runningCount > 0 ? '$runningCount running' : null,
          actions: [
            _SmallButton(
              icon: Icons.open_in_full,
              tooltip: 'Maximize',
              color: colors.textMuted,
              onTap: () => _maximize(SlotContentType.history, 'History'),
            ),
            if (entries.isNotEmpty) _SmallButton(icon: Icons.clear_all, tooltip: 'Clear completed', onTap: () => core.history.clearCompleted()),
          ],
        ),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No history', style: AppTheme.bodySmall.copyWith(color: colors.textMuted)),
          )
        else
          for (final entry in entries) _DropdownHistoryRow(entry: entry, onClose: onClose, parentContext: parentContext),
      ],
    );
  }

  Future<void> _maximize(SlotContentType type, String label) async {
    // Close dropdown first so it doesn't block the dialog
    onClose();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!parentContext.mounted) return;
    final slot = await PaneTargetSelector.show(parentContext, title: 'Maximize To', subtitle: label);
    if (slot != null) {
      core.layout.assignSlot(slot, type);
    }
  }
}

/// Section header matching the pane header style (without drag handle)
class _DropdownSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final String? info;
  final List<Widget>? actions;

  const _DropdownSectionHeader({
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

    return Container(
      height: sizes.paneHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.paneHeaderButtonPadding * 2),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: sizes.paneHeaderIconSize, color: iconColor ?? colors.textMuted),
          SizedBox(width: sizes.paneHeaderButtonPadding * 1.5),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: sizes.paneHeaderTitleFontSize),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (info != null) ...[
            Text(info!, style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.paneHeaderInfoFontSize)),
            SizedBox(width: sizes.paneHeaderButtonPadding * 2),
          ],
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Group row with expandable tasks (matches _GroupRow in layout_pane.dart)
class _DropdownGroupRow extends StatefulWidget {
  final TaskGroup group;
  final VoidCallback onClose;
  final BuildContext parentContext;

  const _DropdownGroupRow({required this.group, required this.onClose, required this.parentContext});

  @override
  State<_DropdownGroupRow> createState() => _DropdownGroupRowState();
}

class _DropdownGroupRowState extends State<_DropdownGroupRow> {
  bool _isExpanded = true;
  bool _isHovered = false;

  void _showContextMenu(Offset position) {
    final colors = AppColorsExtension.of(context);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: colors.border)),
      items: [
        _buildContextMenuItem('run_all', Icons.play_arrow, 'Run All', AppColors.running),
        _buildContextMenuItem('edit', Icons.edit, 'Edit', colors.textPrimary),
        const PopupMenuDivider(),
        _buildContextMenuItem('delete', Icons.delete, 'Delete Group', AppColors.error),
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

  PopupMenuItem<String> _buildContextMenuItem(String value, IconData icon, String label, Color color) {
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
    final ctx = widget.parentContext;
    widget.onClose();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!ctx.mounted) return;

    final templates = widget.group.getOrderedTemplates(core.templates.all);
    for (final template in templates) {
      if (!ctx.mounted) return;
      final targetSlot = await PaneTargetSelector.show(ctx, title: 'Select Pane for ${template.name}', subtitle: '${templates.indexOf(template) + 1} of ${templates.length}');
      if (targetSlot == null || !ctx.mounted) break;
      final task = await PlaceholderInputDialog.launchTemplate(ctx, template);
      if (task == null || !ctx.mounted) break;
      core.layout.assignTerminal(targetSlot, task.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final sizes = core.settings.uiSizes;
    final templates = widget.group.getOrderedTemplates(core.templates.all);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
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
        if (_isExpanded)
          for (final template in templates) _DropdownTemplateRow(template: template, inGroup: true, groupId: widget.group.id, onClose: widget.onClose, parentContext: widget.parentContext),
      ],
    );
  }
}

/// Single template row (matches _TemplateRow in layout_pane.dart)
class _DropdownTemplateRow extends StatefulWidget {
  final Template template;
  final bool inGroup;
  final String? groupId;
  final VoidCallback onClose;
  final BuildContext parentContext;

  const _DropdownTemplateRow({required this.template, this.inGroup = false, this.groupId, required this.onClose, required this.parentContext});

  @override
  State<_DropdownTemplateRow> createState() => _DropdownTemplateRowState();
}

class _DropdownTemplateRowState extends State<_DropdownTemplateRow> {
  bool _isHovered = false;

  Future<void> _launchTemplate() async {
    final ctx = widget.parentContext;
    widget.onClose();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!ctx.mounted) return;

    final targetSlot = await PaneTargetSelector.show(ctx, title: 'Select Target Pane', subtitle: widget.template.name);
    if (targetSlot == null || !ctx.mounted) return;

    final task = await PlaceholderInputDialog.launchTemplate(ctx, widget.template);
    if (task != null) {
      core.layout.assignTerminal(targetSlot, task.id);
    }
  }

  void _showContextMenu(Offset position) {
    final colors = AppColorsExtension.of(context);
    final isGrouped = widget.groupId != null;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: colors.border)),
      items: [
        _buildContextMenuItem('run', Icons.play_arrow, 'Run', AppColors.running, colors),
        _buildContextMenuItem('edit', Icons.edit, 'Edit', colors.textPrimary, colors),
        _buildContextMenuItem('duplicate', Icons.copy, 'Duplicate', colors.textPrimary, colors),
        if (isGrouped) ...[const PopupMenuDivider(), _buildContextMenuItem('ungroup', Icons.folder_off, 'Remove from Group', AppColors.warning, colors)],
        const PopupMenuDivider(),
        _buildContextMenuItem('delete', Icons.delete, 'Delete', AppColors.error, colors),
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

  PopupMenuItem<String> _buildContextMenuItem(String value, IconData icon, String label, Color color, AppColorScheme colors) {
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
    final colors = AppColorsExtension.of(context);
    final sizes = core.settings.uiSizes;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showContextMenu(details.globalPosition),
        child: Container(
          height: sizes.taskRowHeight,
          padding: EdgeInsets.symmetric(horizontal: sizes.taskRowHeight / 4.5),
          decoration: BoxDecoration(
            color: _isHovered ? colors.surfaceLighter : Colors.transparent,
            border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
          ),
          child: Row(
            children: [
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
        ),
      ),
    );
  }
}

/// Single history row (matches _HistoryRow in layout_pane.dart)
class _DropdownHistoryRow extends StatefulWidget {
  final HistoryEntry entry;
  final VoidCallback onClose;
  final BuildContext parentContext;

  const _DropdownHistoryRow({required this.entry, required this.onClose, required this.parentContext});

  @override
  State<_DropdownHistoryRow> createState() => _DropdownHistoryRowState();
}

class _DropdownHistoryRowState extends State<_DropdownHistoryRow> {
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
    if (isToday) return time;
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
    final ctx = widget.parentContext;
    widget.onClose();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!ctx.mounted) return;
    final targetSlot = await PaneTargetSelector.show(ctx, title: 'Select Pane', subtitle: widget.entry.name);
    if (targetSlot != null) {
      core.layout.assignTerminal(targetSlot, widget.entry.taskId!);
    }
  }

  Future<void> _viewLog() async {
    final ctx = widget.parentContext;
    widget.onClose();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!ctx.mounted) return;
    final targetSlot = await PaneTargetSelector.show(ctx, title: 'View Log', subtitle: widget.entry.name);
    if (targetSlot != null) {
      core.layout.assignSlot(targetSlot, SlotContentType.terminal, 'log_${widget.entry.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final sizes = core.settings.uiSizes;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        if (widget.entry.isRunning && widget.entry.taskId != null) {
          core.layout.setHoveredTaskId(widget.entry.taskId);
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
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
            Container(
              width: sizes.historyStatusDotSize,
              height: sizes.historyStatusDotSize,
              decoration: BoxDecoration(color: _statusColor(colors), shape: BoxShape.circle),
            ),
            SizedBox(width: sizes.historyStatusDotSize),
            if (widget.entry.emoji.isNotEmpty) ...[
              Text(widget.entry.emoji, style: TextStyle(fontSize: sizes.historyEmojiSize)),
              SizedBox(width: sizes.historyEmojiSize / 2),
            ],
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
                        Text(
                          _formatTime(widget.entry.startedAt),
                          style: AppTheme.monoSmall.copyWith(color: colors.textMuted, fontSize: sizes.historyTimeFontSize),
                        ),
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
              _PaneIndicatorDropdown(
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

/// Small header button
class _SmallButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallButton({required this.icon, this.color, required this.tooltip, required this.onTap});

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
class _PaneIndicatorDropdown extends StatelessWidget {
  final String? taskId;
  final VoidCallback onTap;
  final double iconSize;

  const _PaneIndicatorDropdown({required this.taskId, required this.onTap, required this.iconSize});

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
