import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/slot_assignment.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/layout_dropdown.dart';
import '../widgets/layout_builder.dart';
import '../widgets/minimized_panes_dropdown.dart';
import '../widgets/pane_target_selector.dart';

class ProcessManagerScreen extends StatefulWidget {
  const ProcessManagerScreen({super.key});

  @override
  State<ProcessManagerScreen> createState() => _ProcessManagerScreenState();
}

class _ProcessManagerScreenState extends State<ProcessManagerScreen> {
  Future<void> _openResources() async {
    // Check if resources is already visible
    if (core.layout.isResourcesVisible) {
      // Already visible, no need to open again
      return;
    }

    // Show pane selector
    final targetSlot = await PaneTargetSelector.show(
      context,
      title: 'Open Resources',
      subtitle: 'Select a pane for resource monitor',
    );

    if (targetSlot == null || !mounted) return;

    // Assign resources to the selected slot
    core.layout.assignSlot(targetSlot, SlotContentType.resources);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final styles = AppTheme.of(context);

    return Container(
      color: colors.background,
      child: Column(
        children: [
          _buildToolbar(colors, styles.scale),
          const Expanded(
            child: PaneLayoutBuilder(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(AppColorScheme colors, double scale) {
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
          Icon(Icons.terminal, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('Process Manager', style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
          const Spacer(),
          // Resources button
          ListenableBuilder(
            listenable: core,
            builder: (context, _) {
              final isVisible = core.layout.isResourcesVisible;
              return Tooltip(
                message: isVisible ? 'Resources visible' : 'Open Resources',
                child: InkWell(
                  onTap: _openResources,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.monitor_heart,
                      size: 16,
                      color: isVisible ? AppColors.info : colors.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const MinimizedPanesDropdown(),
          const SizedBox(width: 8),
          const LayoutDropdown(),
        ],
      ),
    );
  }
}
