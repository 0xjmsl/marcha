import 'package:flutter/material.dart';
import '../models/layout_node.dart';
import '../state/layout_state.dart';

class PaneLeaf extends StatefulWidget {
  final LayoutNode node;
  final LayoutState state;

  const PaneLeaf({
    super.key,
    required this.node,
    required this.state,
  });

  @override
  State<PaneLeaf> createState() => _PaneLeafState();
}

class _PaneLeafState extends State<PaneLeaf> {
  bool _hovering = false;

  // Colors for pane slots so we can tell them apart.
  static const _colors = [
    Color(0xFF1a1a2e),
    Color(0xFF16213e),
    Color(0xFF0f3460),
    Color(0xFF1a0a2e),
    Color(0xFF2e1a1a),
    Color(0xFF1a2e1a),
    Color(0xFF2e2e1a),
    Color(0xFF1a2e2e),
  ];

  @override
  Widget build(BuildContext context) {
    final slot = widget.node.slotIndex ?? 0;
    final color = _colors[slot % _colors.length];
    final isOnlyPane = widget.state.root.isLeaf;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: _hovering
                ? Colors.blue.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            // Pane content placeholder.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pane ${slot}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.node.id,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons — show on hover.
            if (_hovering)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.vertical_split,
                      tooltip: 'Split Right',
                      onPressed: () => widget.state.splitNode(
                        widget.node.id,
                        SplitDirection.row,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _ActionButton(
                      icon: Icons.horizontal_split,
                      tooltip: 'Split Down',
                      onPressed: () => widget.state.splitNode(
                        widget.node.id,
                        SplitDirection.column,
                      ),
                    ),
                    if (!isOnlyPane) ...[
                      const SizedBox(width: 4),
                      _ActionButton(
                        icon: Icons.close,
                        tooltip: 'Close Pane',
                        onPressed: () =>
                            widget.state.closeNode(widget.node.id),
                        color: Colors.red,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.color ?? Colors.blue;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hovering
                  ? baseColor.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hovering
                    ? baseColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovering
                  ? baseColor
                  : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
