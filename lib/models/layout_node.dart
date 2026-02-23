enum SplitDirection { row, column }

class LayoutNode {
  /// Unique id for widget keys and identification.
  final String id;

  /// Flex weight within the parent split.
  double flex;

  /// Non-null when this is a split (row or column).
  SplitDirection? direction;

  /// Children when this is a split node.
  List<LayoutNode> children;

  /// Slot index assigned to leaf nodes.
  int? slotIndex;

  LayoutNode._({
    required this.id,
    this.flex = 1.0,
    this.direction,
    List<LayoutNode>? children,
    this.slotIndex,
  }) : children = children ?? [];

  /// Create a leaf node.
  factory LayoutNode.leaf({required int slotIndex, double flex = 1.0}) {
    return LayoutNode._(
      id: _nextId(),
      flex: flex,
      slotIndex: slotIndex,
    );
  }

  /// Create a split node.
  factory LayoutNode.split({
    required SplitDirection direction,
    required List<LayoutNode> children,
    double flex = 1.0,
  }) {
    return LayoutNode._(
      id: _nextId(),
      flex: flex,
      direction: direction,
      children: children,
    );
  }

  bool get isLeaf => direction == null;
  bool get isSplit => direction != null;

  /// Split this leaf into two panes.
  /// Returns the new slot index assigned to the new pane.
  int split(SplitDirection dir, int nextSlotIndex) {
    assert(isLeaf, 'Can only split leaf nodes');
    final original = LayoutNode.leaf(slotIndex: slotIndex!);
    final newPane = LayoutNode.leaf(slotIndex: nextSlotIndex);
    direction = dir;
    children = [original, newPane];
    slotIndex = null;
    return nextSlotIndex;
  }

  /// Remove a child node and collapse if only one child remains.
  void removeChild(String childId) {
    children.removeWhere((c) => c.id == childId);
    if (children.length == 1) {
      final remaining = children.first;
      if (remaining.isLeaf) {
        slotIndex = remaining.slotIndex;
        direction = null;
        children = [];
      } else {
        direction = remaining.direction;
        children = remaining.children;
      }
    }
  }

  /// Find the parent of a node with the given id.
  LayoutNode? findParent(String targetId) {
    for (final child in children) {
      if (child.id == targetId) return this;
      final found = child.findParent(targetId);
      if (found != null) return found;
    }
    return null;
  }

  /// Find a node by id.
  LayoutNode? findById(String targetId) {
    if (id == targetId) return this;
    for (final child in children) {
      final found = child.findById(targetId);
      if (found != null) return found;
    }
    return null;
  }

  /// Count all leaf nodes.
  int get leafCount {
    if (isLeaf) return 1;
    return children.fold(0, (sum, c) => sum + c.leafCount);
  }

  /// Get all slot indices in the tree.
  List<int> get allSlotIndices {
    if (isLeaf) return [if (slotIndex != null) slotIndex!];
    return children.expand((c) => c.allSlotIndices).toList();
  }

  // Simple incrementing id generator.
  static int _idCounter = 0;
  static String _nextId() => 'node_${_idCounter++}';
  static void resetIdCounter() => _idCounter = 0;

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'flex': flex,
    };
    if (direction != null) {
      map['direction'] = direction!.name;
      map['children'] = children.map((c) => c.toJson()).toList();
    }
    if (slotIndex != null) {
      map['slotIndex'] = slotIndex;
    }
    return map;
  }

  /// Deserialize from JSON map.
  factory LayoutNode.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final flex = (json['flex'] as num?)?.toDouble() ?? 1.0;
    final dirStr = json['direction'] as String?;
    final slotIndex = json['slotIndex'] as int?;

    SplitDirection? direction;
    List<LayoutNode> children = [];

    if (dirStr != null) {
      direction = SplitDirection.values.firstWhere(
        (d) => d.name == dirStr,
        orElse: () => SplitDirection.row,
      );
      final childrenJson = json['children'] as List<dynamic>?;
      if (childrenJson != null) {
        children = childrenJson
            .map((c) => LayoutNode.fromJson(c as Map<String, dynamic>))
            .toList();
      }
    }

    // Track max id counter for future node generation
    final idNum = int.tryParse(id.replaceFirst('node_', ''));
    if (idNum != null && idNum >= _idCounter) {
      _idCounter = idNum + 1;
    }

    return LayoutNode._(
      id: id,
      flex: flex,
      direction: direction,
      children: children,
      slotIndex: slotIndex,
    );
  }

  @override
  String toString() {
    if (isLeaf) return 'Leaf($slotIndex, flex: ${flex.toStringAsFixed(2)})';
    final dir = direction == SplitDirection.row ? 'Row' : 'Column';
    return '$dir(flex: ${flex.toStringAsFixed(2)}, children: $children)';
  }
}
