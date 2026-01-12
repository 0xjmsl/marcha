import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart' as xterm;
import '../core/core.dart';
import '../models/task.dart';
import '../theme/terminal_theme.dart';
import '../theme/app_colors.dart';

/// Embedded terminal view that displays a Task's terminal.
/// Terminal state lives in the Task, this widget just renders it.
class TerminalView extends StatefulWidget {
  final Task task;
  final VoidCallback? onClose;

  const TerminalView({
    super.key,
    required this.task,
    this.onClose,
  });

  @override
  State<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<TerminalView> {
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
    final scale = core.settings.textScale;

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
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(
          bottom: BorderSide(color: theme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.task.isRunning ? theme.runningColor : theme.stoppedColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: Text(
              widget.task.name,
              style: TextStyle(
                color: theme.foreground.withValues(alpha: 0.7),
                fontSize: 12,
                fontFamily: 'Consolas',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // PID badge
          if (widget.task.pid != null) ...[
            GestureDetector(
              onTap: _copyPid,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.titleBarBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PID ${widget.task.pid}',
                    style: TextStyle(
                      color: theme.foreground.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Action buttons
          if (widget.task.isRunning) ...[
            _HeaderIconButton(
              icon: Icons.stop,
              tooltip: 'Stop (Ctrl+C)',
              color: AppColors.warning,
              onTap: () => core.tasks.stop(widget.task.id),
            ),
            const SizedBox(width: 4),
            _HeaderIconButton(
              icon: Icons.close,
              tooltip: 'Kill',
              color: AppColors.error,
              onTap: () {
                core.tasks.kill(widget.task.id);
                widget.onClose?.call();
              },
            ),
          ] else ...[
            _HeaderIconButton(
              icon: Icons.close,
              tooltip: 'Close',
              color: theme.foreground.withValues(alpha: 0.5),
              onTap: widget.onClose,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

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
