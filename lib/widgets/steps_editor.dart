import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/task_step.dart';

/// Widget for editing automation steps on a template
class StepsEditor extends StatefulWidget {
  final List<TaskStep> steps;
  final ValueChanged<List<TaskStep>> onChanged;
  final bool initiallyExpanded;

  const StepsEditor({
    super.key,
    required this.steps,
    required this.onChanged,
    this.initiallyExpanded = false,
  });

  @override
  State<StepsEditor> createState() => _StepsEditorState();
}

class _StepsEditorState extends State<StepsEditor>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late List<_StepEditData> _stepData;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || widget.steps.isNotEmpty;
    _stepData = widget.steps.map((s) => _StepEditData.fromStep(s)).toList();

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
  void didUpdateWidget(StepsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if external steps changed
    if (widget.steps.length != _stepData.length) {
      _stepData = widget.steps.map((s) => _StepEditData.fromStep(s)).toList();
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    for (final data in _stepData) {
      data.dispose();
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
    final steps = _stepData.map((d) => d.toStep()).toList();
    widget.onChanged(steps);
  }

  void _addStep() {
    setState(() {
      _stepData.add(_StepEditData(
        id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
        expectController: TextEditingController(text: r'\$'),
        sendController: TextEditingController(),
        timeout: 30000,
      ));
    });
    _notifyChange();
  }

  void _removeStep(int index) {
    if (_stepData.length <= 1) return;
    setState(() {
      _stepData[index].dispose();
      _stepData.removeAt(index);
    });
    _notifyChange();
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _stepData.removeAt(oldIndex);
      _stepData.insert(newIndex, item);
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
          // Header
          _buildHeader(colors),
          // Content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Column(
              children: [
                // Info banner
                _buildInfoBanner(colors),
                // Steps list
                if (_stepData.isNotEmpty) _buildStepsList(colors),
                // Add step button
                _buildAddStepButton(colors),
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
            // Terminal-style icon
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _stepData.isNotEmpty
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : colors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _stepData.isNotEmpty
                      ? AppColors.accent.withValues(alpha: 0.3)
                      : colors.border,
                ),
              ),
              child: Icon(
                Icons.auto_mode,
                size: 16,
                color: _stepData.isNotEmpty
                    ? AppColors.accent
                    : colors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Automation Steps',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (_stepData.isEmpty)
                    Text(
                      'Optional - automate terminal interactions',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (_stepData.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_stepData.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
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
                    text: 'Steps run after the task starts. Each step ',
                  ),
                  TextSpan(
                    text: 'waits for a pattern',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const TextSpan(text: ' in the output, then '),
                  TextSpan(
                    text: 'sends a command',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const TextSpan(text: '. Use '),
                  TextSpan(
                    text: '{{placeholders}}',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      color: AppColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const TextSpan(text: ' for dynamic values.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _stepData.length,
        onReorder: _reorderSteps,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final elevation = lerpDouble(0, 8, animation.value)!;
              return Material(
                elevation: elevation,
                color: Colors.transparent,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                child: child,
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          return _buildStepItem(index, colors);
        },
      ),
    );
  }

  Widget _buildStepItem(int index, AppColorScheme colors) {
    final data = _stepData[index];

    return Container(
      key: ValueKey(data.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // Step header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Step number badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.2),
                        AppColors.accent.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'STEP ${index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                // Timeout dropdown
                _buildTimeoutDropdown(data, colors),
                const SizedBox(width: 4),
                // Remove button
                if (_stepData.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removeStep(index),
                    color: colors.textMuted,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: const Size(28, 28),
                    ),
                    tooltip: 'Remove step',
                  ),
              ],
            ),
          ),
          // Fields
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Expect field
                _buildPatternField(
                  data.expectController,
                  'Wait for pattern',
                  r'Regex pattern (e.g., \$ or password:)',
                  Icons.search,
                  colors,
                ),
                const SizedBox(height: 10),
                // Send field with placeholder highlighting
                _buildCommandField(
                  data.sendController,
                  'Then send',
                  'Command to send (optional)',
                  Icons.send,
                  colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    AppColorScheme colors,
  ) {
    return Row(
      children: [
        // Label
        SizedBox(
          width: 104,
          child: Row(
            children: [
              Icon(icon, size: 14, color: colors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Field
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (_) => _notifyChange(),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12,
              color: colors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
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
                borderSide: const BorderSide(color: AppColors.info, width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommandField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    AppColorScheme colors,
  ) {
    return Row(
      children: [
        // Label
        SizedBox(
          width: 104,
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.running.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Field with placeholder highlighting
        Expanded(
          child: _PlaceholderHighlightField(
            controller: controller,
            hint: hint,
            colors: colors,
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeoutDropdown(_StepEditData data, AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: data.timeout,
          isDense: true,
          icon: Icon(Icons.timer_outlined,
              size: 14, color: colors.textMuted),
          style: TextStyle(
            fontSize: 11,
            color: colors.textSecondary,
            fontFamily: 'Consolas',
          ),
          dropdownColor: colors.surface,
          items: const [
            DropdownMenuItem(value: 5000, child: Text('5s')),
            DropdownMenuItem(value: 10000, child: Text('10s')),
            DropdownMenuItem(value: 30000, child: Text('30s')),
            DropdownMenuItem(value: 60000, child: Text('60s')),
            DropdownMenuItem(value: 120000, child: Text('2m')),
            DropdownMenuItem(value: 300000, child: Text('5m')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => data.timeout = v);
              _notifyChange();
            }
          },
        ),
      ),
    );
  }

  Widget _buildAddStepButton(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: _addStep,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.border,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Add Step',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field that highlights {{placeholders}} with accent color
class _PlaceholderHighlightField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final AppColorScheme colors;
  final ValueChanged<String>? onChanged;

  const _PlaceholderHighlightField({
    required this.controller,
    required this.hint,
    required this.colors,
    this.onChanged,
  });

  @override
  State<_PlaceholderHighlightField> createState() =>
      _PlaceholderHighlightFieldState();
}

class _PlaceholderHighlightFieldState
    extends State<_PlaceholderHighlightField> {
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      style: TextStyle(
        fontFamily: 'Consolas',
        fontSize: 12,
        color: widget.colors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
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
          borderSide:
              const BorderSide(color: AppColors.running, width: 1.5),
        ),
        // Show placeholder indicator if text contains placeholders
        suffixIcon: _hasPlaceholders()
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Tooltip(
                  message: 'Contains placeholders',
                  child: Icon(
                    Icons.code,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 30),
      ),
    );
  }

  bool _hasPlaceholders() {
    return RegExp(r'\{\{[^}]+\}\}').hasMatch(widget.controller.text);
  }
}

/// Internal data class for step editing
class _StepEditData {
  final String id;
  final TextEditingController expectController;
  final TextEditingController sendController;
  int timeout;

  _StepEditData({
    required this.id,
    required this.expectController,
    required this.sendController,
    required this.timeout,
  });

  factory _StepEditData.fromStep(TaskStep step) {
    return _StepEditData(
      id: step.id,
      expectController: TextEditingController(text: step.expect),
      sendController: TextEditingController(text: step.send ?? ''),
      timeout: step.timeout,
    );
  }

  TaskStep toStep() {
    return TaskStep(
      id: id,
      expect: expectController.text,
      send: sendController.text.isEmpty ? null : sendController.text,
      timeout: timeout,
    );
  }

  void dispose() {
    expectController.dispose();
    sendController.dispose();
  }
}

/// Helper for animations
double? lerpDouble(num? a, num? b, double t) {
  if (a == b || (a?.isNaN == true) && (b?.isNaN == true)) {
    return a?.toDouble();
  }
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}
