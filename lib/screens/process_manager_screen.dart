import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/layout_dropdown.dart';
import '../widgets/layout_builder.dart';
import '../widgets/minimized_panes_dropdown.dart';

class ProcessManagerScreen extends StatelessWidget {
  const ProcessManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildToolbar(colors),
          const Expanded(
            child: PaneLayoutBuilder(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(AppColorScheme colors) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('Process Manager', style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
          const Spacer(),
          const MinimizedPanesDropdown(),
          const SizedBox(width: 8),
          const LayoutDropdown(),
        ],
      ),
    );
  }
}
