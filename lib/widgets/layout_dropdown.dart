import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/layout_preset.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LayoutDropdown extends StatelessWidget {
  const LayoutDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        final currentPreset = core.layout.currentPreset;
        final options = core.layout.layoutOptions();

        return PopupMenuButton<LayoutPreset>(
          tooltip: 'Change layout',
          offset: const Offset(0, 40),
          onSelected: (preset) {
            core.layout.setLayout(preset);
          },
          itemBuilder: (context) {
            return options.map((preset) {
              final isSelected = preset == currentPreset;
              return PopupMenuItem<LayoutPreset>(
                value: preset,
                child: Row(
                  children: [
                    Icon(
                      preset.icon,
                      size: 18,
                      color: isSelected ? AppColors.accent : colors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      preset.displayName,
                      style: AppTheme.bodyNormal.copyWith(
                        color: isSelected ? AppColors.accent : colors.textPrimary,
                      ),
                    ),
                    if (isSelected) ...[
                      const Spacer(),
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.accent,
                      ),
                    ],
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
                Icon(
                  currentPreset.icon,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  currentPreset.displayName,
                  style: AppTheme.monoNormal.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_drop_down,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
