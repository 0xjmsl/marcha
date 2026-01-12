import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Sidebar navigation item
class SidebarItem {
  final String id;
  final String title;
  final IconData icon;

  const SidebarItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

/// Collapsible sidebar navigation widget
class AppSidebar extends StatefulWidget {
  final List<SidebarItem> items;
  final String selectedId;
  final ValueChanged<String> onItemSelected;
  final bool initiallyExpanded;

  const AppSidebar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onItemSelected,
    this.initiallyExpanded = false,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Base dimensions (scaled by text size)
  static const double _baseCollapsedWidth = 40.0;
  static const double _baseExpandedWidth = 200.0;
  static const double _baseIconAreaWidth = 40.0;
  static const double _baseItemHeight = 32.0;
  static const double _baseHeaderHeight = 36.0;
  static const double _baseIconSize = 18.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.initiallyExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTheme.of(context);
    final colors = AppColorsExtension.of(context);
    final scale = styles.scale;

    final collapsedWidth = _baseCollapsedWidth * scale;
    final expandedWidth = _baseExpandedWidth * scale;
    final currentWidth = collapsedWidth + (expandedWidth - collapsedWidth) * _animation.value;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: currentWidth + 1,
          decoration: BoxDecoration(
            color: colors.sidebarBackground,
            border: Border(
              right: BorderSide(color: colors.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              _buildHeader(styles, colors),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: widget.items.map((item) => _buildItem(item, styles, colors)).toList(),
                ),
              ),
              _buildToggleButton(styles, colors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppTextStyles styles, AppColorScheme colors) {
    final headerHeight = _baseHeaderHeight * styles.scale;
    final iconAreaWidth = _baseIconAreaWidth * styles.scale;

    return Container(
      height: headerHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Icon area - fixed width, always centered
          SizedBox(
            width: iconAreaWidth,
            child: Center(
              child: Icon(
                Icons.rocket_launch,
                color: AppColors.info,
                size: styles.iconNormal,
              ),
            ),
          ),
          // Text area - clips and fades
          Expanded(
            child: ClipRect(
              child: Opacity(
                opacity: _animation.value,
                child: Text(
                  'Marcha',
                  style: styles.headingSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(SidebarItem item, AppTextStyles styles, AppColorScheme colors) {
    final isSelected = item.id == widget.selectedId;
    final itemHeight = _baseItemHeight * styles.scale;
    final iconAreaWidth = _baseIconAreaWidth * styles.scale;
    final iconSize = _baseIconSize * styles.scale;
    // Margin animates from 4 (collapsed) to 6 (expanded)
    final margin = 4.0 + (2.0 * _animation.value);

    return Tooltip(
      message: _animation.value < 0.5 ? item.title : '',
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: () => widget.onItemSelected(item.id),
        child: Container(
          height: itemHeight,
          margin: EdgeInsets.symmetric(horizontal: margin, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? colors.sidebarSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Icon area - fixed width
              SizedBox(
                width: iconAreaWidth - (margin * 2),
                child: Center(
                  child: Icon(
                    item.icon,
                    size: iconSize,
                    color: isSelected ? colors.textBright : colors.textSecondary,
                  ),
                ),
              ),
              // Text area - clips and fades
              Expanded(
                child: ClipRect(
                  child: Opacity(
                    opacity: _animation.value,
                    child: Text(
                      item.title,
                      style: styles.sidebarLabel.copyWith(
                        color: isSelected ? colors.textBright : colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(AppTextStyles styles, AppColorScheme colors) {
    final itemHeight = _baseItemHeight * styles.scale;
    final iconAreaWidth = _baseIconAreaWidth * styles.scale;
    final iconSize = styles.iconSmall;

    return Container(
      height: itemHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: InkWell(
        onTap: _toggle,
        child: Row(
          children: [
            // Icon area - fixed width
            SizedBox(
              width: iconAreaWidth,
              child: Center(
                child: Transform.rotate(
                  angle: _animation.value * 3.14159, // 180 degrees
                  child: Icon(
                    Icons.chevron_right,
                    size: iconSize,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
            // Text area - clips and fades
            Expanded(
              child: ClipRect(
                child: Opacity(
                  opacity: _animation.value,
                  child: Text(
                    'Collapse',
                    style: styles.bodySmall.copyWith(color: colors.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
