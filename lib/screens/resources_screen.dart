import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final styles = AppTheme.of(context);

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildHeader(colors, styles.scale),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.monitor_heart,
                    size: 64,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Resources Monitor',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coming soon...',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors, double scale) {
    return Container(
      height: 36 * scale,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.monitor_heart, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('Resources', style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
          const Spacer(),
        ],
      ),
    );
  }
}
