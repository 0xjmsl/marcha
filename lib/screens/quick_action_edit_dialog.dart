import 'package:flutter/material.dart';
import '../models/quick_action.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_picker.dart';

/// Dialog for creating or editing a quick action
class QuickActionEditDialog extends StatefulWidget {
  final QuickAction? action; // null = create new

  const QuickActionEditDialog({super.key, this.action});

  /// Show as a dialog and return the saved action (or null if cancelled)
  static Future<QuickAction?> show(BuildContext context, {QuickAction? action}) {
    final colors = AppColorsExtension.of(context);
    return showDialog<QuickAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 350),
          child: QuickActionEditDialog(action: action),
        ),
      ),
    );
  }

  @override
  State<QuickActionEditDialog> createState() => _QuickActionEditDialogState();
}

class _QuickActionEditDialogState extends State<QuickActionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _commandController;
  late String _selectedEmoji;

  bool get isEditing => widget.action != null;

  @override
  void initState() {
    super.initState();
    final a = widget.action;
    _nameController = TextEditingController(text: a?.name ?? '');
    _commandController = TextEditingController(text: a?.command ?? '');
    _selectedEmoji = a?.emoji ?? '⚡';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _pickEmoji() async {
    final emoji = await showEmojiPicker(context, currentEmoji: _selectedEmoji);
    if (emoji != null) {
      setState(() => _selectedEmoji = emoji);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final action = QuickAction(
      id: widget.action?.id ?? QuickAction.generateId(),
      name: _nameController.text.trim(),
      command: _commandController.text.trim(),
      emoji: _selectedEmoji,
    );

    Navigator.pop(context, action);
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
                isEditing ? 'Edit Quick Action' : 'New Quick Action',
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
                          maxLength: 15,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (v.trim().length > 15) return 'Max 15 characters';
                            return null;
                          },
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Name',
                            hintText: 'rebuild',
                            counterText: '',
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
                  const SizedBox(height: 16),
                  // Command field
                  TextFormField(
                    controller: _commandController,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontFamily: 'Consolas',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Command',
                      hintText: 'npm run build',
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
                  const SizedBox(height: 12),
                  // Help text
                  Text(
                    'The command will be sent to the terminal when the button is clicked.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
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
}
