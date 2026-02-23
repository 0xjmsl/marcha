import 'package:flutter/material.dart';
import '../models/layout_node.dart';
import '../state/layout_state.dart';
import 'pane_leaf.dart';
import 'resizable_divider.dart';

/// Recursively renders a LayoutNode tree into nested Row/Column/Leaf widgets.
class LayoutTree extends StatelessWidget {
  final LayoutNode node;
  final LayoutState state;

  const LayoutTree({
    super.key,
    required this.node,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return _buildNode(node);
  }

  Widget _buildNode(LayoutNode node) {
    if (node.isLeaf) {
      return PaneLeaf(
        key: ValueKey(node.id),
        node: node,
        state: state,
      );
    }

    // Wrap in LayoutBuilder to get the actual size for divider drag calculations.
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = node.direction == SplitDirection.row
            ? constraints.maxWidth
            : constraints.maxHeight;

        final children = <Widget>[];
        for (var i = 0; i < node.children.length; i++) {
          final child = node.children[i];

          children.add(
            Expanded(
              flex: (child.flex * 1000).round(),
              child: _buildNode(child),
            ),
          );

          if (i < node.children.length - 1) {
            final dividerIndex = i;
            children.add(
              ResizableDivider(
                key: ValueKey('divider_${node.id}_$dividerIndex'),
                axis: node.direction == SplitDirection.row
                    ? Axis.vertical
                    : Axis.horizontal,
                onDrag: (delta) {
                  state.updateFlex(node.id, dividerIndex, delta, totalSize);
                },
                onDoubleTap: () {
                  final c1 = node.children[dividerIndex];
                  final c2 = node.children[dividerIndex + 1];
                  final avg = (c1.flex + c2.flex) / 2;
                  c1.flex = avg;
                  c2.flex = avg;
                  state.updateFlex(node.id, dividerIndex, 0, 1);
                },
              ),
            );
          }
        }

        if (node.direction == SplitDirection.row) {
          return Row(children: children);
        } else {
          return Column(children: children);
        }
      },
    );
  }
}
