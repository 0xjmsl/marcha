import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Widget for editing per-template environment variables
class EnvVarsEditor extends StatefulWidget {
  final Map<String, String> envVars;
  final ValueChanged<Map<String, String>> onChanged;
  final bool initiallyExpanded;

  const EnvVarsEditor({
    super.key,
    required this.envVars,
    required this.onChanged,
    this.initiallyExpanded = false,
  });

  @override
  State<EnvVarsEditor> createState() => _EnvVarsEditorState();
}

class _EnvVarsEditorState extends State<EnvVarsEditor>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late List<_EnvVarEditData> _entries;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || widget.envVars.isNotEmpty;
    _entries = widget.envVars.entries
        .map((e) => _EnvVarEditData(
              id: DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
                  e.key,
              keyController: TextEditingController(text: e.key),
              valueController: TextEditingController(text: e.value),
            ))
        .toList();

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    if (_isExpanded) {
      _expandController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _notifyChange() {
    final map = <String, String>{};
    for (final entry in _entries) {
      final key = entry.keyController.text.trim();
      if (key.isNotEmpty) {
        map[key] = entry.valueController.text;
      }
    }
    widget.onChanged(map);
  }

  void _addEntry() {
    setState(() {
      _entries.add(_EnvVarEditData(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        keyController: TextEditingController(),
        valueController: TextEditingController(),
      ));
    });
    _notifyChange();
  }

  void _removeEntry(int index) {
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(colors),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                _buildInfoBanner(colors),
                if (_entries.isNotEmpty) _buildEntriesList(colors),
                _buildAddButton(colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors) {
    return InkWell(
      onTap: _toggleExpanded,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(10),
        bottom: _isExpanded ? Radius.zero : const Radius.circular(10),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceLight,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(10),
            bottom: _isExpanded ? Radius.zero : const Radius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _entries.isNotEmpty
                    ? AppColors.warning.withValues(alpha: 0.15)
                    : colors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _entries.isNotEmpty
                      ? AppColors.warning.withValues(alpha: 0.3)
                      : colors.border,
                ),
              ),
              child: Icon(
                Icons.vpn_key_outlined,
                size: 16,
                color: _entries.isNotEmpty
                    ? AppColors.warning
                    : colors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Environment Variables',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (_entries.isEmpty)
                    Text(
                      'Optional - set env vars for this task',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (_entries.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_entries.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                    fontFamily: 'Consolas',
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(AppColorScheme colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: colors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Variables are merged with system environment at launch. '
                        'Template vars ',
                  ),
                  TextSpan(
                    text: 'override',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const TextSpan(text: ' system vars with the same name. Use '),
                  TextSpan(
                    text: '{{placeholders}}',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const TextSpan(text: ' in values for dynamic input.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          for (int i = 0; i < _entries.length; i++)
            _buildEntryItem(i, colors),
        ],
      ),
    );
  }

  Widget _buildEntryItem(int index, AppColorScheme colors) {
    final data = _entries[index];

    return Container(
      key: ValueKey(data.id),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key field
          Expanded(
            flex: 2,
            child: TextField(
              controller: data.keyController,
              onChanged: (_) => _notifyChange(),
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'KEY',
                hintStyle: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 12,
                  color: colors.textMuted,
                ),
                filled: true,
                fillColor: colors.surface,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: AppColors.info, width: 1.5),
                ),
              ),
            ),
          ),
          // Equals sign
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              '=',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textMuted,
              ),
            ),
          ),
          // Value field (obscured by default)
          Expanded(
            flex: 3,
            child: _ObscuredValueField(
              controller: data.valueController,
              colors: colors,
              onChanged: (_) => _notifyChange(),
            ),
          ),
          const SizedBox(width: 4),
          // Delete button
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => _removeEntry(index),
            color: colors.textMuted,
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(28, 28),
            ),
            tooltip: 'Remove variable',
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: _addEntry,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Add Variable',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Value field with obscure toggle (values are often secrets)
class _ObscuredValueField extends StatefulWidget {
  final TextEditingController controller;
  final AppColorScheme colors;
  final ValueChanged<String>? onChanged;

  const _ObscuredValueField({
    required this.controller,
    required this.colors,
    this.onChanged,
  });

  @override
  State<_ObscuredValueField> createState() => _ObscuredValueFieldState();
}

class _ObscuredValueFieldState extends State<_ObscuredValueField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      obscureText: _obscured,
      style: TextStyle(
        fontFamily: 'Consolas',
        fontSize: 12,
        color: widget.colors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'value',
        hintStyle: TextStyle(
          fontFamily: 'Consolas',
          fontSize: 12,
          color: widget.colors.textMuted,
        ),
        filled: true,
        fillColor: widget.colors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: widget.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: widget.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.info, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscured ? Icons.visibility_off : Icons.visibility,
            size: 16,
            color: widget.colors.textMuted,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30),
          tooltip: _obscured ? 'Show value' : 'Hide value',
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 30),
      ),
    );
  }
}

/// Internal data class for env var editing
class _EnvVarEditData {
  final String id;
  final TextEditingController keyController;
  final TextEditingController valueController;

  _EnvVarEditData({
    required this.id,
    required this.keyController,
    required this.valueController,
  });

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
