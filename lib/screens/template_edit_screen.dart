import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../core/core.dart';
import '../models/template.dart';
import '../models/task_step.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_picker.dart';
import '../widgets/steps_editor.dart';

/// Screen for creating or editing a template
class TemplateEditScreen extends StatefulWidget {
  final Template? template; // null = create new

  const TemplateEditScreen({super.key, this.template});

  /// Show as a dialog and return the saved template (or null if cancelled)
  static Future<Template?> show(BuildContext context, {Template? template}) {
    final colors = AppColorsExtension.of(context);
    return showDialog<Template>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: TemplateEditScreen(template: template),
        ),
      ),
    );
  }

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late final TextEditingController _argumentsController;
  late final TextEditingController _workingDirController;
  late final TextEditingController _descriptionController;
  late String _selectedEmoji;
  late List<TaskStep> _steps;

  bool get isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _commandController = TextEditingController(text: t?.command ?? '');
    _argumentsController = TextEditingController(
      text: t?.arguments.join(' ') ?? '',
    );
    _workingDirController = TextEditingController(text: t?.workingDirectory ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _selectedEmoji = t?.emoji ?? '🚀';
    _steps = List.from(t?.steps ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _argumentsController.dispose();
    _workingDirController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPicker(context, currentEmoji: _selectedEmoji);
    if (emoji != null) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  Future<void> _browseWorkingDir() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _workingDirController.text = result;
    }
  }

  String get _commandPreview {
    final cmd = _commandController.text.trim();
    final args = _argumentsController.text.trim();
    if (cmd.isEmpty) return '';
    return args.isEmpty ? cmd : '$cmd $args';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final arguments = _argumentsController.text.trim().isEmpty
        ? <String>[]
        : _argumentsController.text.trim().split(' ');

    final workingDir = _workingDirController.text.trim().isEmpty
        ? null
        : _workingDirController.text.trim();

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    final template = Template(
      id: widget.template?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      command: _commandController.text.trim(),
      arguments: arguments,
      workingDirectory: workingDir,
      emoji: _selectedEmoji,
      description: description,
      steps: _steps,
    );

    if (isEditing) {
      await core.templates.update(template);
    } else {
      await core.templates.add(template);
    }

    if (mounted) {
      Navigator.pop(context, template);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                isEditing ? 'Edit Template' : 'New Template',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji + Name row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji picker
                      InkWell(
                        onTap: _pickEmoji,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.surfaceLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.border),
                          ),
                          child: Center(
                            child: Text(
                              _selectedEmoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name field
                      Expanded(
                        child: _buildField(
                          colors: colors,
                          controller: _nameController,
                          label: 'Task Name',
                          hint: 'My Task',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Command
                  _buildField(
                    colors: colors,
                    controller: _commandController,
                    label: 'Command',
                    hint: 'python, npm, code...',
                    prefixIcon: Icons.terminal,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                    mono: true,
                  ),
                  const SizedBox(height: 8),
                  // Quick presets
                  Wrap(
                    spacing: 8,
                    children: [
                      _PresetChip(
                        label: 'VS Code',
                        onTap: () => _commandController.text = 'code',
                      ),
                      _PresetChip(
                        label: 'Python',
                        onTap: () => _commandController.text = 'python',
                      ),
                      _PresetChip(
                        label: 'NPM',
                        onTap: () => _commandController.text = 'npm',
                      ),
                      _PresetChip(
                        label: 'Node',
                        onTap: () => _commandController.text = 'node',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Arguments
                  _buildField(
                    colors: colors,
                    controller: _argumentsController,
                    label: 'Arguments',
                    hint: 'run dev, install, ...',
                    prefixIcon: Icons.code,
                    mono: true,
                  ),
                  const SizedBox(height: 16),
                  // Working Directory
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          colors: colors,
                          controller: _workingDirController,
                          label: 'Working Directory',
                          hint: 'C:\\Projects\\myapp',
                          prefixIcon: Icons.folder_outlined,
                          mono: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _browseWorkingDir,
                        icon: const Icon(Icons.folder_open, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surfaceLight,
                          foregroundColor: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Description
                  _buildField(
                    colors: colors,
                    controller: _descriptionController,
                    label: 'Description (optional)',
                    hint: 'What does this task do?',
                    prefixIcon: Icons.notes,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  // Automation Steps
                  StepsEditor(
                    steps: _steps,
                    onChanged: (steps) {
                      setState(() => _steps = steps);
                    },
                    initiallyExpanded: _steps.isNotEmpty,
                  ),
                  const SizedBox(height: 20),
                  // Command Preview
                  _buildCommandPreview(colors),
                ],
              ),
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

  Widget _buildField({
    required AppColorScheme colors,
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? prefixIcon,
    String? Function(String?)? validator,
    bool mono = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(
        color: colors.textPrimary,
        fontFamily: mono ? 'Consolas' : null,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: colors.textMuted),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: colors.textMuted)
            : null,
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
          borderSide: const BorderSide(color: AppColors.info, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildCommandPreview(AppColorScheme colors) {
    return ListenableBuilder(
      listenable: Listenable.merge([_commandController, _argumentsController]),
      builder: (context, _) {
        final preview = _commandPreview;
        if (preview.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PREVIEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  // Terminal dots
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.stopped,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      color: AppColors.running,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Command
                  Expanded(
                    child: SelectableText(
                      '\$ $preview',
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  // Copy button
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: preview));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    color: colors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colors.surfaceLight,
      side: BorderSide(color: colors.border),
      labelStyle: TextStyle(
        color: colors.textSecondary,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
