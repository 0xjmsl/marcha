import 'package:flutter/material.dart';


class ResizableDivider extends StatefulWidget {
  final Axis axis;
  final VoidCallback? onDoubleTap;
  final void Function(double delta) onDrag;

  const ResizableDivider({
    super.key,
    required this.axis,
    required this.onDrag,
    this.onDoubleTap,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    final active = _hovering || _dragging;

    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeRow
          : SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onPanUpdate: (details) {
          final delta = isHorizontal ? details.delta.dy : details.delta.dx;
          widget.onDrag(delta);
        },
        onPanStart: (_) => setState(() => _dragging = true),
        onPanEnd: (_) => setState(() => _dragging = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isHorizontal ? double.infinity : (active ? 6 : 1),
          height: isHorizontal ? (active ? 6 : 1) : double.infinity,
          decoration: BoxDecoration(
            color: active
                ? Colors.blue.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: active
              ? Center(
                  child: _buildGripDots(isHorizontal),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGripDots(bool isHorizontal) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Container(
          width: 2,
          height: 2,
          margin: EdgeInsets.symmetric(
            horizontal: isHorizontal ? 2 : 0,
            vertical: isHorizontal ? 0 : 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
