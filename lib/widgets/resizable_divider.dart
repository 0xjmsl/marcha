import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/core.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Which ratio group this divider controls
enum RatioGroup { main, nested1, nested2 }

/// A draggable divider for resizing panes
class ResizableDivider extends StatefulWidget {
  final Axis axis;
  final RatioGroup ratioGroup;
  final int dividerIndex;

  const ResizableDivider({
    super.key,
    required this.axis,
    required this.ratioGroup,
    required this.dividerIndex,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);
    final isVertical = widget.axis == Axis.vertical;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Get the total size in the drag direction
        final totalSize =
            isVertical ? constraints.maxHeight : constraints.maxWidth;

        return MouseRegion(
          cursor: isVertical
              ? SystemMouseCursors.resizeColumn
              : SystemMouseCursors.resizeRow,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) {
            if (!_isDragging) {
              setState(() => _isHovering = false);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart:
                isVertical ? (_) => _onDragStart() : null,
            onHorizontalDragUpdate: isVertical
                ? (details) => _onDragUpdate(details.delta.dx, totalSize)
                : null,
            onHorizontalDragEnd:
                isVertical ? (_) => _onDragEnd() : null,
            onVerticalDragStart:
                !isVertical ? (_) => _onDragStart() : null,
            onVerticalDragUpdate: !isVertical
                ? (details) => _onDragUpdate(details.delta.dy, totalSize)
                : null,
            onVerticalDragEnd:
                !isVertical ? (_) => _onDragEnd() : null,
            // Stack: line fills full size, grip handle overlays on hover
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The actual divider line - full height/width, 1px thick
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isVertical ? 1 : double.infinity,
                  height: !isVertical ? 1 : double.infinity,
                  color: _isHovering || _isDragging
                      ? colors.borderLight
                      : colors.border,
                ),
                // Invisible hit target area (wider for easier grabbing)
                Container(
                  width: isVertical ? 9 : double.infinity,
                  height: !isVertical ? 9 : double.infinity,
                  color: Colors.transparent,
                ),
                // Grip handle on hover
                if (_isHovering || _isDragging)
                  _buildGripHandle(isVertical, colors),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGripHandle(bool isVertical, AppColorScheme colors) {
    // Build grip dots
    const dotSize = 3.0;
    const dotSpacing = 4.0;
    const dotCount = 3;

    final dots = List.generate(dotCount, (index) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          color: colors.textMuted.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
      );
    });

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isVertical ? 0 : 8,
        vertical: isVertical ? 8 : 0,
      ),
      child: isVertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: dots
                  .expand((dot) => [dot, SizedBox(height: dotSpacing)])
                  .take(dotCount * 2 - 1)
                  .toList(),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: dots
                  .expand((dot) => [dot, SizedBox(width: dotSpacing)])
                  .take(dotCount * 2 - 1)
                  .toList(),
            ),
    );
  }

  void _onDragStart() {
    setState(() => _isDragging = true);
    HapticFeedback.selectionClick();
  }

  void _onDragUpdate(double delta, double totalSize) {
    switch (widget.ratioGroup) {
      case RatioGroup.main:
        core.layout.updateMainRatios(widget.dividerIndex, delta, totalSize);
        break;
      case RatioGroup.nested1:
        core.layout.updateNested1Ratios(widget.dividerIndex, delta, totalSize);
        break;
      case RatioGroup.nested2:
        core.layout.updateNested2Ratios(widget.dividerIndex, delta, totalSize);
        break;
    }
  }

  void _onDragEnd() {
    setState(() {
      _isDragging = false;
      _isHovering = false;
    });
    core.layout.notifyDragEnd();
  }
}
