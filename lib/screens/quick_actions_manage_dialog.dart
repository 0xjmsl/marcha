import 'package:flutter/material.dart';
import '../models/quick_action.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'quick_action_edit_dialog.dart';

/// Dialog for managing quick actions (reorder, edit, delete)
class QuickActionsManageDialog extends StatefulWidget {
  final List<QuickAction> actions;

  const QuickActionsManageDialog({super.key, required this.actions});

  /// Show as a dialog and return the modified list (or null if cancelled)
  static Future<List<QuickAction>?> show(
    BuildContext context, {
    required List<QuickAction> actions,
  }) {
    final colors = AppColorsExtension.of(context);
    return showDialog<List<QuickAction>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 500),
          child: QuickActionsManageDialog(actions: actions),
        ),
      ),
    );
  }

  @override
  State<QuickActionsManageDialog> createState() =>
      _QuickActionsManageDialogState();
}

class _QuickActionsManageDialogState extends State<QuickActionsManageDialog> {
  late List<QuickAction> _actions;

  @override
  void initState() {
    super.initState();
    _actions = List.from(widget.actions);
  }

  void _reorderActions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _actions.removeAt(oldIndex);
      _actions.insert(newIndex, item);
    });
  }

  Future<void> _editAction(int index) async {
    final edited = await QuickActionEditDialog.show(
      context,
      action: _actions[index],
    );
    if (edited != null) {
      setState(() => _actions[index] = edited);
    }
  }

  void _deleteAction(int index) {
    setState(() => _actions.removeAt(index));
  }

  Future<void> _addAction() async {
    final action = await QuickActionEditDialog.show(context);
    if (action != null) {
      setState(() => _actions.add(action));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 24, color: AppColors.warning),
              const SizedBox(width: 12),
              Text(
                'Manage Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
                color: colors.textMuted,
              ),
            ],
          ),
        ),
        // Actions list
        Expanded(
          child: _actions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_outlined,
                        size: 48,
                        color: colors.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No quick actions yet',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _addAction,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Quick Action'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Info box
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 16, color: AppColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Drag to reorder. Changes are saved when you click Save.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Reorderable list
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: colors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.border),
                        ),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          buildDefaultDragHandles: false,
                          itemCount: _actions.length,
                          onReorder: _reorderActions,
                          itemBuilder: (context, index) {
                            final action = _actions[index];
                            return _ActionRow(
                              key: ValueKey(action.id),
                              index: index,
                              action: action,
                              onEdit: () => _editAction(index),
                              onDelete: () => _deleteAction(index),
                            );
                          },
                        ),
                      ),
                    ),
                    // Add button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addAction,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Quick Action'),
                        ),
                      ),
                    ),
                  ],
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, _actions),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final int index;
  final QuickAction action;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionRow({
    super.key,
    required this.index,
    required this.action,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.drag_indicator, size: 16, color: colors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          // Emoji
          Text(action.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          // Name and command
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  action.command,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                    fontFamily: 'Consolas',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onEdit,
            color: colors.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Edit',
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: onDelete,
            color: AppColors.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
