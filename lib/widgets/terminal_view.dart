import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;
import '../core/core.dart';
import '../models/task.dart';
import '../models/template.dart';
import '../models/quick_action.dart';
import '../theme/terminal_theme.dart';
import '../theme/app_colors.dart';
import '../screens/quick_action_edit_dialog.dart';
import '../screens/quick_actions_manage_dialog.dart';
import 'pane_drag_overlay.dart';

/// Embedded terminal view that displays a Task's terminal.
/// Terminal state lives in the Task, this widget just renders it.
class TerminalView extends StatefulWidget {
  final Task task;
  final int slotIndex;
  final VoidCallback? onClose;

  const TerminalView({
    super.key,
    required this.task,
    required this.slotIndex,
    this.onClose,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
  /// Get the template associated with this task
  Template? get _template {
    final templateId = widget.task.templateId;
    if (templateId == null) return null;
    return core.templates.getById(templateId);
  }

  /// Get the working directory for the task
  String? get _workingDirectory {
    return widget.task.workingDirectory ?? _template?.workingDirectory;
  }

  void _copyPid() {
    if (widget.task.pid != null) {
      Clipboard.setData(ClipboardData(text: widget.task.pid.toString()));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PID ${widget.task.pid} copied'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Open Windows Explorer at the working directory
  void _openExplorer() {
    final workDir = _workingDirectory;
    if (workDir != null && workDir.isNotEmpty) {
      Process.run('explorer.exe', [workDir]);
    }
  }

  /// Execute a quick action command
  void _executeQuickAction(QuickAction action) {
    if (widget.task.isRunning) {
      widget.task.write('${action.command}\r\n');
    }
  }

  /// Add a new quick action to the template
  Future<void> _addQuickAction() async {
    final template = _template;
    if (template == null) return;

    final action = await QuickActionEditDialog.show(context);
    if (action != null) {
      final updatedTemplate = template.copyWith(
        quickActions: [...template.quickActions, action],
      );
      await core.templates.update(updatedTemplate);
      setState(() {});
    }
  }

  /// Manage quick actions (reorder, edit, delete)
  Future<void> _manageQuickActions() async {
    final template = _template;
    if (template == null) return;

    final result = await QuickActionsManageDialog.show(
      context,
      actions: template.quickActions,
    );
    if (result != null) {
      final updatedTemplate = template.copyWith(quickActions: result);
      await core.templates.update(updatedTemplate);
      setState(() {});
    }
  }

  xterm.TerminalTheme _buildXtermTheme(TerminalTheme theme) {
    return xterm.TerminalTheme(
      cursor: theme.promptColor,
      selection: theme.promptColor.withValues(alpha: 0.3),
      foreground: theme.foreground,
      background: theme.background,
      black: Colors.black,
      red: theme.errorColor,
      green: theme.successColor,
      yellow: theme.warningColor,
      blue: theme.promptColor,
      magenta: const Color(0xFFAA00AA),
      cyan: const Color(0xFF00AAAA),
      white: Colors.white,
      brightBlack: Colors.grey,
      brightRed: theme.errorColor,
      brightGreen: theme.successColor,
      brightYellow: theme.warningColor,
      brightBlue: theme.promptColor,
      brightMagenta: const Color(0xFFFF55FF),
      brightCyan: const Color(0xFF55FFFF),
      brightWhite: Colors.white,
      searchHitBackground: theme.promptColor.withValues(alpha: 0.3),
      searchHitBackgroundCurrent: theme.promptColor.withValues(alpha: 0.5),
      searchHitForeground: theme.foreground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = core.settings.terminalTheme;
    final scale = core.settings.terminalFontScale;

    return Container(
      color: theme.background,
      child: Column(
        children: [
          // Flat header with bottom border (embedded style)
          _buildHeader(theme),
          // Terminal content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0, top: 20),
              child: xterm.TerminalView(
                widget.task.terminal,
                controller: widget.task.terminalController,
                autofocus: true,
                backgroundOpacity: 1.0,
                hardwareKeyboardOnly: true,
                theme: _buildXtermTheme(theme),
                textStyle: xterm.TerminalStyle(
                  fontSize: 14.0 * scale,
                  fontFamily: 'Consolas',
                ),
                onSecondaryTapDown: (details, offset) async {
                  final controller = widget.task.terminalController;
                  final terminal = widget.task.terminal;
                  final selection = controller.selection;
                  if (selection != null) {
                    final text = terminal.buffer.getText(selection);
                    controller.clearSelection();
                    await Clipboard.setData(ClipboardData(text: text));
                  } else {
                    final data = await Clipboard.getData('text/plain');
                    final text = data?.text;
                    if (text != null) {
                      terminal.paste(text);
                    }
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TerminalTheme theme) {
    final template = _template;
    final quickActions = template?.quickActions ?? [];
    final hasWorkingDir = _workingDirectory != null && _workingDirectory!.isNotEmpty;
    final sizes = core.settings.uiSizes;

    final header = Container(
      height: sizes.terminalHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.terminalHeaderHeight / 3.5),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          bottom: BorderSide(color: theme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(Icons.drag_indicator, size: sizes.terminalDragIconSize, color: theme.foreground.withValues(alpha: 0.3)),
          SizedBox(width: sizes.terminalDragIconSize / 3),
          // Status indicator
          Container(
            width: sizes.terminalStatusIndicatorSize,
            height: sizes.terminalStatusIndicatorSize,
            decoration: BoxDecoration(
              color: widget.task.isRunning ? theme.runningColor : theme.stoppedColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: sizes.terminalStatusIndicatorSize),
          // Title
          Expanded(
            child: Text(
              widget.task.name,
              style: TextStyle(
                color: theme.foreground.withValues(alpha: 0.7),
                fontSize: sizes.terminalTitleFontSize,
                fontFamily: 'Consolas',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Quick action buttons (emoji only)
          if (quickActions.isNotEmpty) ...[
            for (final action in quickActions) ...[
              _QuickActionButton(
                action: action,
                theme: theme,
                onTap: () => _executeQuickAction(action),
                onSecondaryTap: _manageQuickActions,
                emojiSize: sizes.terminalQuickActionEmojiSize,
              ),
              SizedBox(width: sizes.terminalDragIconSize / 6),
            ],
            SizedBox(width: sizes.terminalDragIconSize / 3),
          ],
          // Add quick action button (only if template exists)
          if (template != null) ...[
            _HeaderIconButton(
              icon: Icons.add,
              tooltip: 'Add Quick Action',
              color: theme.foreground.withValues(alpha: 0.5),
              onTap: _addQuickAction,
              iconSize: sizes.terminalActionIconSize,
            ),
            SizedBox(width: sizes.terminalDragIconSize / 3),
          ],
          // PID badge
          if (widget.task.pid != null) ...[
            GestureDetector(
              onTap: _copyPid,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: sizes.terminalPidFontSize * 0.6, vertical: sizes.terminalPidFontSize * 0.2),
                  decoration: BoxDecoration(
                    color: theme.titleBarBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PID ${widget.task.pid}',
                    style: TextStyle(
                      color: theme.foreground.withValues(alpha: 0.5),
                      fontSize: sizes.terminalPidFontSize,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: sizes.terminalHeaderHeight / 3.5),
          ],
          // Explorer button
          _HeaderIconButton(
            icon: Icons.folder_open,
            tooltip: hasWorkingDir ? 'Open in Explorer' : 'No working directory',
            color: hasWorkingDir
                ? theme.foreground.withValues(alpha: 0.5)
                : theme.foreground.withValues(alpha: 0.2),
            onTap: hasWorkingDir ? _openExplorer : null,
            iconSize: sizes.terminalActionIconSize,
          ),
          SizedBox(width: sizes.terminalDragIconSize / 3),
          // Action buttons
          if (widget.task.isRunning) ...[
            _HeaderIconButton(
              icon: Icons.stop,
              tooltip: 'Stop (Ctrl+C)',
              color: AppColors.warning,
              onTap: () => core.tasks.stop(widget.task.id),
              iconSize: sizes.terminalActionIconSize,
            ),
            SizedBox(width: sizes.terminalDragIconSize / 3),
            _HeaderIconButton(
              icon: Icons.close,
              tooltip: 'Kill',
              color: AppColors.error,
              onTap: () {
                core.tasks.kill(widget.task.id);
                widget.onClose?.call();
              },
              iconSize: sizes.terminalActionIconSize,
            ),
          ] else ...[
            _HeaderIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              color: theme.foreground.withValues(alpha: 0.5),
              onTap: widget.onClose,
              iconSize: sizes.terminalActionIconSize,
            ),
          ],
        ],
      ),
    );

    return DraggablePaneHeader(
      slotIndex: widget.slotIndex,
      child: header,
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  final double? iconSize;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
    this.iconSize,
  });

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

/// Button for quick actions showing emoji only
class _QuickActionButton extends StatelessWidget {
  final QuickAction action;
  final TerminalTheme theme;
  final VoidCallback onTap;
  final VoidCallback onSecondaryTap;
  final double? emojiSize;

  const _QuickActionButton({
    required this.action,
    required this.theme,
    required this.onTap,
    required this.onSecondaryTap,
    this.emojiSize,
  });

  @override
  Widget build(BuildContext context) {
    final size = emojiSize ?? 12.0;
    return Tooltip(
      message: '${action.name}: ${action.command}',
      child: GestureDetector(
        onSecondaryTap: onSecondaryTap,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: size / 3, vertical: size / 6),
            decoration: BoxDecoration(
              color: theme.titleBarBackground,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              action.emoji,
              style: TextStyle(fontSize: size),
            ),
          ),
        ),
      ),
    );
  }
}
