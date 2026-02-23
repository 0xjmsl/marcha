import 'package:flutter/material.dart';
import '../models/layout_node.dart';

class LayoutState extends ChangeNotifier {
  LayoutNode _root;
  int _nextSlotIndex;

  LayoutState()
      : _root = LayoutNode.leaf(slotIndex: 0),
        _nextSlotIndex = 1;

  LayoutNode get root => _root;

  /// Split a leaf node in the given direction.
  void splitNode(String nodeId, SplitDirection direction) {
    final node = _root.findById(nodeId);
    if (node == null || !node.isLeaf) return;
    node.split(direction, _nextSlotIndex);
    _nextSlotIndex++;
    notifyListeners();
  }

  /// Close/remove a leaf node.
  void closeNode(String nodeId) {
    // Don't allow closing the last pane.
    if (_root.isLeaf) return;

    final parent = _root.findParent(nodeId);
    if (parent != null) {
      parent.removeChild(nodeId);
      notifyListeners();
    }
  }

  /// Update flex ratios for a divider drag.
  void updateFlex(String parentId, int dividerIndex, double delta, double totalSize) {
    final parent = _root.findById(parentId);
    if (parent == null || parent.isLeaf) return;

    final children = parent.children;
    if (dividerIndex < 0 || dividerIndex >= children.length - 1) return;

    final child1 = children[dividerIndex];
    final child2 = children[dividerIndex + 1];

    final totalFlex = child1.flex + child2.flex;
    final ratio = delta / totalSize;
    final newFlex1 = (child1.flex + ratio * totalFlex).clamp(0.1, totalFlex - 0.1);
    final newFlex2 = totalFlex - newFlex1;

    child1.flex = newFlex1;
    child2.flex = newFlex2;
    notifyListeners();
  }

  /// Reset to a single pane.
  void reset() {
    LayoutNode.resetIdCounter();
    _root = LayoutNode.leaf(slotIndex: 0);
    _nextSlotIndex = 1;
    notifyListeners();
  }

  /// Quick preset: apply a predefined tree structure.
  void applyPreset(LayoutNode preset, int nextSlot) {
    _root = preset;
    _nextSlotIndex = nextSlot;
    notifyListeners();
  }
}
