import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/layout_node.dart';
import 'layout_pane.dart';
import 'resizable_divider.dart';

/// Builds the layout grid by recursively walking the LayoutNode tree
class PaneLayoutBuilder extends StatelessWidget {
  const PaneLayoutBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        return _buildNode(core.layout.root);
      },
    );
  }

  Widget _buildNode(LayoutNode node) {
    if (node.isLeaf) {
      return LayoutPane(slotIndex: node.slotIndex!, nodeId: node.id);
    }

    // Split node — build Row or Column with Expanded children and dividers
    final isRow = node.direction == SplitDirection.row;
    final children = <Widget>[];

    for (int i = 0; i < node.children.length; i++) {
      final child = node.children[i];
      children.add(
        Expanded(
          flex: (child.flex * 100).round(),
          child: _buildNode(child),
        ),
      );

      // Add divider between children (not after last)
      if (i < node.children.length - 1) {
        children.add(
          ResizableDivider(
            axis: isRow ? Axis.vertical : Axis.horizontal,
            parentNodeId: node.id,
            dividerIndex: i,
          ),
        );
      }
    }

    if (isRow) {
      return Row(children: children);
    } else {
      return Column(children: children);
    }
  }
}
