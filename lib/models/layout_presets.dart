import 'package:flutter/material.dart';
import 'layout_node.dart';

/// Descriptor for a layout preset
class PresetInfo {
  final String name;
  final String displayName;
  final IconData icon;
  final ({LayoutNode tree, int nextSlotIndex}) Function() build;

  const PresetInfo({
    required this.name,
    required this.displayName,
    required this.icon,
    required this.build,
  });
}

/// Static factory methods that build LayoutNode trees for each kept preset
class LayoutPresets {
  LayoutPresets._();

  static ({LayoutNode tree, int nextSlotIndex}) single() {
    LayoutNode.resetIdCounter();
    return (tree: LayoutNode.leaf(slotIndex: 0), nextSlotIndex: 1);
  }

  static ({LayoutNode tree, int nextSlotIndex}) twoColumns() {
    LayoutNode.resetIdCounter();
    return (
      tree: LayoutNode.split(
        direction: SplitDirection.row,
        children: [
          LayoutNode.leaf(slotIndex: 0),
          LayoutNode.leaf(slotIndex: 1),
        ],
      ),
      nextSlotIndex: 2,
    );
  }

  static ({LayoutNode tree, int nextSlotIndex}) twoRows() {
    LayoutNode.resetIdCounter();
    return (
      tree: LayoutNode.split(
        direction: SplitDirection.column,
        children: [
          LayoutNode.leaf(slotIndex: 0),
          LayoutNode.leaf(slotIndex: 1),
        ],
      ),
      nextSlotIndex: 2,
    );
  }

  static ({LayoutNode tree, int nextSlotIndex}) fourGrid() {
    LayoutNode.resetIdCounter();
    return (
      tree: LayoutNode.split(
        direction: SplitDirection.column,
        children: [
          LayoutNode.split(
            direction: SplitDirection.row,
            children: [
              LayoutNode.leaf(slotIndex: 0),
              LayoutNode.leaf(slotIndex: 1),
            ],
          ),
          LayoutNode.split(
            direction: SplitDirection.row,
            children: [
              LayoutNode.leaf(slotIndex: 2),
              LayoutNode.leaf(slotIndex: 3),
            ],
          ),
        ],
      ),
      nextSlotIndex: 4,
    );
  }

  static ({LayoutNode tree, int nextSlotIndex}) threeColumns() {
    LayoutNode.resetIdCounter();
    return (
      tree: LayoutNode.split(
        direction: SplitDirection.row,
        children: [
          LayoutNode.leaf(slotIndex: 0),
          LayoutNode.leaf(slotIndex: 1),
          LayoutNode.leaf(slotIndex: 2),
        ],
      ),
      nextSlotIndex: 3,
    );
  }

  static ({LayoutNode tree, int nextSlotIndex}) oneTopTwoByThreeGrid() {
    LayoutNode.resetIdCounter();
    return (
      tree: LayoutNode.split(
        direction: SplitDirection.column,
        children: [
          LayoutNode.leaf(slotIndex: 0),
          LayoutNode.split(
            direction: SplitDirection.column,
            flex: 3.0,
            children: [
              LayoutNode.split(
                direction: SplitDirection.row,
                children: [
                  LayoutNode.leaf(slotIndex: 1),
                  LayoutNode.leaf(slotIndex: 2),
                ],
              ),
              LayoutNode.split(
                direction: SplitDirection.row,
                children: [
                  LayoutNode.leaf(slotIndex: 3),
                  LayoutNode.leaf(slotIndex: 4),
                ],
              ),
              LayoutNode.split(
                direction: SplitDirection.row,
                children: [
                  LayoutNode.leaf(slotIndex: 5),
                  LayoutNode.leaf(slotIndex: 6),
                ],
              ),
            ],
          ),
        ],
      ),
      nextSlotIndex: 7,
    );
  }

  /// All available presets
  static final List<PresetInfo> presets = [
    PresetInfo(
      name: 'single',
      displayName: '1 Pane',
      icon: Icons.square_outlined,
      build: single,
    ),
    PresetInfo(
      name: 'twoColumns',
      displayName: '2 Columns',
      icon: Icons.view_column,
      build: twoColumns,
    ),
    PresetInfo(
      name: 'twoRows',
      displayName: '2 Rows',
      icon: Icons.view_agenda,
      build: twoRows,
    ),
    PresetInfo(
      name: 'fourGrid',
      displayName: '2x2 Grid',
      icon: Icons.grid_view,
      build: fourGrid,
    ),
    PresetInfo(
      name: 'threeColumns',
      displayName: '3 Columns',
      icon: Icons.view_week,
      build: threeColumns,
    ),
    PresetInfo(
      name: 'oneTopTwoByThreeGrid',
      displayName: '1 Top + 2x3',
      icon: Icons.apps,
      build: oneTopTwoByThreeGrid,
    ),
  ];

  /// Look up a preset by name. Falls back to threeColumns.
  static PresetInfo byName(String name) {
    return presets.firstWhere(
      (p) => p.name == name,
      orElse: () => presets.firstWhere((p) => p.name == 'threeColumns'),
    );
  }
}
