import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/layout_presets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Layout controls: management mode toggle + preset dropdown
class LayoutControls extends StatelessWidget {
  const LayoutControls({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        final isManagementMode = core.layout.isPaneManagementMode;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Management mode toggle
            Tooltip(
              message: isManagementMode ? 'Exit pane management' : 'Manage panes',
              child: InkWell(
                onTap: () => core.layout.togglePaneManagementMode(),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isManagementMode ? AppColors.accent.withValues(alpha: 0.15) : colors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isManagementMode ? AppColors.accent.withValues(alpha: 0.5) : colors.border,
                    ),
                  ),
                  child: Icon(
                    Icons.dashboard_customize,
                    size: 18,
                    color: isManagementMode ? AppColors.accent : colors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Preset dropdown
            PopupMenuButton<String>(
              tooltip: 'Layout presets',
              offset: const Offset(0, 40),
              onSelected: (presetName) {
                core.layout.applyPreset(presetName);
              },
              itemBuilder: (context) {
                return LayoutPresets.presets.map((preset) {
                  return PopupMenuItem<String>(
                    value: preset.name,
                    child: Row(
                      children: [
                        Icon(preset.icon, size: 18, color: colors.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          preset.displayName,
                          style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceLight,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_week, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Layout',
                      style: AppTheme.monoNormal.copyWith(color: colors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down, size: 18, color: colors.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Keep the old name as an alias for backward compat in imports
typedef LayoutDropdown = LayoutControls;
