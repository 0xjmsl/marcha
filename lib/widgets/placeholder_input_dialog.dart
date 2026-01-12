import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/template.dart';
import '../models/task.dart';
import '../core/core.dart';

/// Dialog that prompts for placeholder values before running a task
class PlaceholderInputDialog extends StatefulWidget {
  final Template template;
  final Set<String> placeholders;

  const PlaceholderInputDialog({
    super.key,
    required this.template,
    required this.placeholders,
  });

  /// Show the dialog and return placeholder values (or null if cancelled)
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required Template template,
    required Set<String> placeholders,
  }) {
    final colors = AppColorsExtension.of(context);
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: PlaceholderInputDialog(
            template: template,
            placeholders: placeholders,
          ),
        ),
      ),
    );
  }

  /// Launch a template, prompting for placeholders if needed
  /// Returns the created Task, or null if user cancelled the dialog
  static Future<Task?> launchTemplate(
    BuildContext context,
    Template template,
  ) async {
    final placeholders = template.placeholders;

    if (placeholders.isEmpty) {
      // No placeholders, launch directly
      return core.tasks.launch(template);
    }

    // Show placeholder input dialog
    final values = await show(
      context,
      template: template,
      placeholders: placeholders,
    );

    if (values == null) {
      // User cancelled
      return null;
    }

    // Launch with substituted values
    return core.tasks.launchWithValues(template, values);
  }

  @override
  State<PlaceholderInputDialog> createState() => _PlaceholderInputDialogState();
}

class _PlaceholderInputDialogState extends State<PlaceholderInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _obscured;
  late final List<String> _orderedPlaceholders;

  @override
  void initState() {
    super.initState();
    // Sort placeholders: password-types first, then alphabetically
    _orderedPlaceholders = widget.placeholders.toList()
      ..sort((a, b) {
        final aIsPassword = _isPasswordType(a);
        final bIsPassword = _isPasswordType(b);
        if (aIsPassword && !bIsPassword) return -1;
        if (!aIsPassword && bIsPassword) return 1;
        return a.compareTo(b);
      });

    _controllers = {
      for (final p in _orderedPlaceholders) p: TextEditingController(),
    };
    _obscured = {
      for (final p in _orderedPlaceholders) p: _isPasswordType(p),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isPasswordType(String name) {
    final lower = name.toLowerCase();
    return lower.contains('password') ||
        lower.contains('pass') ||
        lower.contains('secret') ||
        lower.contains('key') ||
        lower.contains('token');
  }

  String _formatLabel(String name) {
    // Convert snake_case or camelCase to Title Case
    return name
        .replaceAllMapped(RegExp(r'[_-]'), (m) => ' ')
        .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  IconData _getIconForPlaceholder(String name) {
    final lower = name.toLowerCase();
    if (_isPasswordType(lower)) return Icons.lock_outline;
    if (lower.contains('path') || lower.contains('dir') || lower.contains('folder')) {
      return Icons.folder_outlined;
    }
    if (lower.contains('user') || lower.contains('name') || lower.contains('account')) {
      return Icons.person_outline;
    }
    if (lower.contains('host') || lower.contains('server') || lower.contains('ip')) {
      return Icons.dns_outlined;
    }
    if (lower.contains('port')) return Icons.numbers;
    if (lower.contains('email')) return Icons.email_outlined;
    if (lower.contains('url') || lower.contains('link')) return Icons.link;
    if (lower.contains('file')) return Icons.description_outlined;
    return Icons.edit_outlined;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final values = <String, String>{};
    for (final entry in _controllers.entries) {
      values[entry.key] = entry.value.text;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        _buildHeader(colors),
        // Form
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  _buildInfoBanner(colors),
                  const SizedBox(height: 20),
                  // Placeholder fields
                  ..._orderedPlaceholders.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildPlaceholderField(p, colors),
                      )),
                ],
              ),
            ),
          ),
        ),
        // Actions
        _buildActions(colors),
      ],
    );
  }

  Widget _buildHeader(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // Emoji container with glow effect
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.template.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Input Required',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textBright,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.template.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textMuted,
                    fontFamily: 'Consolas',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            color: colors.textMuted,
            style: IconButton.styleFrom(
              backgroundColor: colors.surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.dynamic_form_outlined,
              size: 16,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Fill in the values below. They will replace {{placeholders}} in the command and steps.',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderField(String name, AppColorScheme colors) {
    final isPassword = _isPasswordType(name);
    final isObscured = _obscured[name] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with placeholder syntax
        Row(
          children: [
            Icon(
              _getIconForPlaceholder(name),
              size: 14,
              color: colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              _formatLabel(name),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '{{$name}}',
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Consolas',
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Input field
        TextFormField(
          controller: _controllers[name],
          obscureText: isObscured,
          validator: (v) =>
              v == null || v.isEmpty ? 'This field is required' : null,
          style: TextStyle(
            color: colors.textPrimary,
            fontFamily: isPassword ? 'Consolas' : null,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: isPassword ? 'Enter ${_formatLabel(name).toLowerCase()}...' : 'Value for $name',
            hintStyle: TextStyle(color: colors.textMuted),
            filled: true,
            fillColor: colors.surfaceLight,
            prefixIcon: isPassword
                ? Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.warning.withValues(alpha: 0.7),
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isObscured ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() => _obscured[name] = !isObscured);
                    },
                    color: colors.textMuted,
                  )
                : null,
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
              borderSide: BorderSide(
                color: isPassword ? AppColors.warning : AppColors.info,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          // Placeholder count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 14, color: colors.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${widget.placeholders.length} placeholder${widget.placeholders.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textMuted,
                    fontFamily: 'Consolas',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Run Task'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.running,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
