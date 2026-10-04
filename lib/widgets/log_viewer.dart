import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/core.dart';
import '../models/terminal_log.dart';

/// A stored terminal log in the terminal theme: header with copy / export /
/// close, then the selectable output. Shared by the Process Manager's log
/// pane (a task's history entry) and the Scheduled screen (a job's run).
class LogViewer extends StatelessWidget {
  final String title;

  /// Called on every build, so a parent rebuild refreshes a live log.
  final Future<TerminalLog?> Function() load;

  /// Base name for the exported file.
  final String exportName;
  final VoidCallback? onClose;

  /// Wraps the header, e.g. in a `DraggablePaneHeader`; also shows a drag handle.
  final Widget Function(Widget header)? wrapHeader;

  const LogViewer({
    super.key,
    required this.title,
    required this.load,
    required this.exportName,
    this.onClose,
    this.wrapHeader,
  });

  Future<void> _copy(BuildContext context) async {
    final log = await load();
    if (!context.mounted) return;
    if (log == null) {
      _snack(context, 'No log data available');
      return;
    }
    await Clipboard.setData(ClipboardData(text: log.plainText));
    if (context.mounted) _snack(context, 'Log copied to clipboard');
  }

  Future<void> _export(BuildContext context) async {
    final log = await load();
    if (!context.mounted) return;
    if (log == null) {
      _snack(context, 'No log data available');
      return;
    }

    // Generate default filename
    final timestamp = DateTime.now();
    final dateStr = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
    final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
    final safeName = exportName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final defaultFileName = '${safeName}_$dateStr-$timeStr.log';

    // Open save file dialog
    final filePath = await FilePicker.platform.saveFile(dialogTitle: 'Export Log', fileName: defaultFileName, type: FileType.custom, allowedExtensions: ['log', 'txt']);
    if (filePath == null) return; // User cancelled

    String? result;
    try {
      await File(filePath).writeAsString(log.plainText);
      result = filePath;
    } catch (_) {}
    if (context.mounted) _snack(context, result != null ? 'Log exported to $result' : 'Failed to export log');
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = core.settings.terminalTheme;
    final sizes = core.settings.uiSizes;

    Widget headerButton(String tooltip, IconData icon, VoidCallback onTap) => Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: EdgeInsets.all(sizes.logContentPadding / 2),
              child: Icon(icon, size: sizes.logHeaderIconSize, color: theme.foreground.withValues(alpha: 0.5)),
            ),
          ),
        );

    final header = Container(
      height: sizes.logHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: sizes.logContentPadding),
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(bottom: BorderSide(color: theme.borderColor, width: 1)),
      ),
      child: Row(
        children: [
          if (wrapHeader != null) ...[
            Icon(Icons.drag_indicator, size: sizes.logHeaderDragIconSize, color: theme.foreground.withValues(alpha: 0.3)),
            SizedBox(width: sizes.logContentPadding / 2),
          ],
          Icon(Icons.description, size: sizes.logHeaderIconSize, color: theme.foreground.withValues(alpha: 0.5)),
          SizedBox(width: sizes.logContentPadding),
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: theme.foreground.withValues(alpha: 0.7), fontSize: sizes.logHeaderTitleFontSize, fontFamily: 'Consolas'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          headerButton('Copy log', Icons.copy, () => _copy(context)),
          SizedBox(width: sizes.logContentPadding / 2),
          headerButton('Export log', Icons.download, () => _export(context)),
          if (onClose != null) ...[
            SizedBox(width: sizes.logContentPadding / 2),
            headerButton('Close', Icons.close, onClose!),
          ],
        ],
      ),
    );

    TextStyle mono(Color color) => TextStyle(color: color, fontFamily: 'Consolas', fontSize: sizes.logContentFontSize);
    final muted = theme.foreground.withValues(alpha: 0.5);

    return Container(
      color: theme.background,
      child: Column(
        children: [
          wrapHeader != null ? wrapHeader!(header) : header,
          // Log content
          Expanded(
            child: FutureBuilder<TerminalLog?>(
              future: load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: muted));
                }

                final log = snapshot.data;
                if (log == null) {
                  return Center(child: Text('No log data available', style: mono(muted)));
                }

                return Padding(
                  padding: EdgeInsets.all(sizes.logContentPadding),
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        // Header info
                        TextSpan(text: '--- Log for ${log.name} ---\n', style: mono(muted)),
                        TextSpan(text: 'Command: ${log.command} ${log.arguments.join(' ')}\n', style: mono(muted)),
                        if (log.workingDirectory != null)
                          TextSpan(text: 'Directory: ${log.workingDirectory!.replaceAll('\\\\', '\\')}\n', style: mono(muted)),
                        TextSpan(text: log.endedAt == null ? 'Running for ${log.durationString}' : 'Duration: ${log.durationString}', style: mono(muted)),
                        if (log.exitCode != null)
                          TextSpan(
                            text: ' | Exit code: ${log.exitCode}',
                            style: mono(log.exitCode == 0 ? theme.successColor : theme.errorColor),
                          ),
                        TextSpan(text: '\n${'─' * 50}\n\n', style: mono(theme.foreground.withValues(alpha: 0.3))),
                        // Log content
                        TextSpan(text: log.lines.join('\n').replaceAll('\\\\', '\\'), style: mono(theme.foreground)),
                      ],
                    ),
                    scrollPhysics: const ClampingScrollPhysics(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
