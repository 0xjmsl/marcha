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
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
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
  late final TextEditingController _scheduleValueController;
  late String _selectedEmoji;
  ScheduleType? _scheduleType;
  late bool _scheduleEnabled;

  bool get isEditing => widget.action != null;

  @override
  void initState() {
    super.initState();
    final a = widget.action;
    _nameController = TextEditingController(text: a?.name ?? '');
    _commandController = TextEditingController(text: a?.command ?? '');
    _scheduleValueController =
        TextEditingController(text: a?.scheduleValue ?? '');
    _selectedEmoji = a?.emoji ?? '⚡';
    _scheduleType = a?.scheduleType;
    _scheduleEnabled = a?.scheduleEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _scheduleValueController.dispose();
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
      scheduleType: _scheduleType,
      scheduleValue: _scheduleType != null
          ? _scheduleValueController.text.trim()
          : null,
      scheduleEnabled: _scheduleEnabled,
    );

    Navigator.pop(context, action);
  }

  String get _scheduleHint {
    switch (_scheduleType) {
      case ScheduleType.clock:
        return '08:00';
      case ScheduleType.interval:
        return '30';
      case ScheduleType.oneShot:
        return '15 or 14:30';
      case null:
        return '';
    }
  }

  String get _scheduleSuffix {
    switch (_scheduleType) {
      case ScheduleType.interval:
        return 'minutes';
      case ScheduleType.oneShot:
        final v = _scheduleValueController.text;
        return v.contains(':') ? '' : 'minutes';
      default:
        return '';
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
                  const SizedBox(height: 16),
                  // Schedule section
                  Row(
                    children: [
                      Text(
                        'Schedule',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 28,
                        child: Switch(
                          value: _scheduleType != null,
                          onChanged: (on) {
                            setState(() {
                              _scheduleType =
                                  on ? ScheduleType.interval : null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_scheduleType != null) ...[
                    const SizedBox(height: 8),
                    // Type selector
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ScheduleType>(
                        segments: const [
                          ButtonSegment(
                            value: ScheduleType.clock,
                            label: Text('Clock', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.schedule, size: 16),
                          ),
                          ButtonSegment(
                            value: ScheduleType.interval,
                            label: Text('Interval', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.repeat, size: 16),
                          ),
                          ButtonSegment(
                            value: ScheduleType.oneShot,
                            label: Text('Once', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.timer, size: 16),
                          ),
                        ],
                        selected: {_scheduleType!},
                        onSelectionChanged: (s) {
                          setState(() => _scheduleType = s.first);
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Value field
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _scheduleValueController,
                            validator: (v) {
                              if (_scheduleType == null) return null;
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontFamily: 'Consolas',
                            ),
                            decoration: InputDecoration(
                              labelText: 'Value',
                              hintText: _scheduleHint,
                              filled: true,
                              fillColor: colors.surfaceLight,
                              suffixText: _scheduleSuffix,
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
                                borderSide:
                                    const BorderSide(color: AppColors.info),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Help text
                  Text(
                    _scheduleType != null
                        ? 'The command will fire automatically on schedule and can still be triggered manually.'
                        : 'The command will be sent to the terminal when the button is clicked.',
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
