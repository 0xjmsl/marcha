import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/template.dart';
import '../models/task_group.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_picker.dart';

/// Screen for creating or editing a task group
class TaskGroupEditScreen extends StatefulWidget {
  final TaskGroup? group; // null = create new

  const TaskGroupEditScreen({super.key, this.group});

  /// Show as a dialog and return the saved group (or null if cancelled)
  static Future<TaskGroup?> show(BuildContext context, {TaskGroup? group}) {
    final colors = AppColorsExtension.of(context);
    return showDialog<TaskGroup>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: TaskGroupEditScreen(group: group),
        ),
      ),
    );
  }

  @override
  State<TaskGroupEditScreen> createState() => _TaskGroupEditScreenState();
}

class _TaskGroupEditScreenState extends State<TaskGroupEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _searchController;
  late String _selectedEmoji;
  late List<String> _selectedTaskIds;

  bool get isEditing => widget.group != null;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameController = TextEditingController(text: g?.name ?? '');
    _searchController = TextEditingController();
    _selectedEmoji = g?.emoji ?? '📁';
    _selectedTaskIds = List<String>.from(g?.taskIds ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPicker(context, currentEmoji: _selectedEmoji);
    if (emoji != null) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  List<Template> get _availableTemplates {
    final search = _searchController.text.toLowerCase();
    return core.templates.all.where((t) {
      if (_selectedTaskIds.contains(t.id)) return false;
      if (search.isEmpty) return true;
      return t.name.toLowerCase().contains(search) ||
          t.command.toLowerCase().contains(search);
    }).toList();
  }

  List<Template> get _selectedTemplates {
    return _selectedTaskIds
        .map((id) => core.templates.getById(id))
        .where((t) => t != null)
        .cast<Template>()
        .toList();
  }

  void _addTask(String id) {
    setState(() => _selectedTaskIds.add(id));
  }

  void _removeTask(String id) {
    setState(() => _selectedTaskIds.remove(id));
  }

  void _reorderTasks(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _selectedTaskIds.removeAt(oldIndex);
      _selectedTaskIds.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTaskIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one task')),
      );
      return;
    }

    final group = TaskGroup(
      id: widget.group?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      taskIds: _selectedTaskIds,
      emoji: _selectedEmoji,
    );

    if (isEditing) {
      await core.templates.updateGroup(group);
    } else {
      await core.templates.addGroup(group);
    }

    if (mounted) {
      Navigator.pop(context, group);
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
              Text(
                _selectedEmoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Text(
                isEditing ? 'Edit Group' : 'New Group',
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
        // Form
        Expanded(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Name + Emoji row
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji picker
                      InkWell(
                        onTap: _pickEmoji,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Center(
                            child: Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name field
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Group Name',
                            hintText: 'My Group',
                            filled: true,
                            fillColor: colors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: colors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.info),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Selected tasks (reorderable)
                if (_selectedTaskIds.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'SELECTED TASKS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedTaskIds.length} tasks',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    constraints: const BoxConstraints(maxHeight: 150),
                    decoration: BoxDecoration(
                      color: colors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      itemCount: _selectedTemplates.length,
                      onReorder: _reorderTasks,
                      itemBuilder: (context, index) {
                        final template = _selectedTemplates[index];
                        return _SelectedTaskRow(
                          key: ValueKey(template.id),
                          index: index,
                          template: template,
                          onRemove: () => _removeTask(template.id),
                        );
                      },
                    ),
                  ),
                  // Info box
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.warningBackground,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tasks will run in this order. Drag to reorder.',
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
                ],
                // Available tasks
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search tasks...',
                      prefixIcon: Icon(Icons.search, size: 18, color: colors.textMuted),
                      filled: true,
                      fillColor: colors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.info),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'AVAILABLE TASKS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_availableTemplates.length} tasks',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.border),
                    ),
                    child: _availableTemplates.isEmpty
                        ? Center(
                            child: Text(
                              'No available tasks',
                              style: TextStyle(color: colors.textMuted),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _availableTemplates.length,
                            itemBuilder: (context, index) {
                              final template = _availableTemplates[index];
                              return _AvailableTaskRow(
                                template: template,
                                onAdd: () => _addTask(template.id),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
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
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: Icon(isEditing ? Icons.save : Icons.add, size: 18),
                label: Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedTaskRow extends StatelessWidget {
  final int index;
  final Template template;
  final VoidCallback onRemove;

  const _SelectedTaskRow({
    super.key,
    required this.index,
    required this.template,
    required this.onRemove,
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
          ReorderableDragStartListener(
            index: index,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.drag_indicator, size: 16, color: colors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(template.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              template.name,
              style: TextStyle(
                fontSize: 13,
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
            color: colors.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _AvailableTaskRow extends StatelessWidget {
  final Template template;
  final VoidCallback onAdd;

  const _AvailableTaskRow({
    required this.template,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return InkWell(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, size: 18, color: AppColors.info),
            const SizedBox(width: 8),
            Text(template.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    template.displayCommand,
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
          ],
        ),
      ),
    );
  }
}
