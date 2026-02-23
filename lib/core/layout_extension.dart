import '../models/app_settings.dart';
import '../models/layout_node.dart';
import '../models/layout_presets.dart';
import '../models/slot_assignment.dart';
import 'core.dart';

/// Extension managing layout state using a recursive split tree
class LayoutExtension {
  final Core _core;

  LayoutExtension(this._core) {
    _initDefaultLayout();
  }

  late LayoutNode _root;
  int _nextSlotIndex = 3;
  List<SlotAssignment> _slots = [];
  bool _paneManagementMode = false;

  // Track if tasksList/history/resources are minimized (not visible in any slot)
  bool _tasksListMinimized = false;
  bool _historyMinimized = false;
  bool _resourcesMinimized = true;

  // Track which task is being hovered in history list (for pane highlight)
  String? _hoveredTaskId;

  // Callback to trigger settings save (set by SettingsExtension)
  void Function()? onLayoutChanged;

  // === GETTERS ===

  /// Get the root layout node tree
  LayoutNode get root => _root;

  /// Get current slot assignments (filtered to active tree slots)
  List<SlotAssignment> get slots {
    final activeIndices = _root.allSlotIndices.toSet();
    return _slots.where((s) => activeIndices.contains(s.slotIndex)).toList();
  }

  /// Get all slot assignments (including non-active, for persistence)
  List<SlotAssignment> get allSlots => List.unmodifiable(_slots);

  /// Get slot count for current layout
  int get slotCount => _root.leafCount;

  /// Check if pane management mode is active
  bool get isPaneManagementMode => _paneManagementMode;

  /// Check if tasksList is minimized
  bool get isTasksListMinimized => _tasksListMinimized;

  /// Check if history is minimized
  bool get isHistoryMinimized => _historyMinimized;

  /// Check if resources is minimized
  bool get isResourcesMinimized => _resourcesMinimized;

  /// Check if tasksList is visible in any active slot
  bool get isTasksListVisible => slots.any((s) => s.isTasksList);

  /// Check if history is visible in any active slot
  bool get isHistoryVisible => slots.any((s) => s.isHistory);

  /// Check if resources is visible in any active slot
  bool get isResourcesVisible => slots.any((s) => s.isResources);

  /// Get the currently hovered task ID (for pane highlight)
  String? get hoveredTaskId => _hoveredTaskId;

  /// Set the hovered task ID (triggers rebuild for pane highlight)
  void setHoveredTaskId(String? taskId) {
    if (_hoveredTaskId == taskId) return;
    _hoveredTaskId = taskId;
    _core.notify();
  }

  // === PANE MANAGEMENT MODE ===

  void togglePaneManagementMode() {
    _paneManagementMode = !_paneManagementMode;
    _core.notify();
  }

  // === LAYOUT INITIALIZATION ===

  void _initDefaultLayout() {
    final result = LayoutPresets.threeColumns();
    _root = result.tree;
    _nextSlotIndex = result.nextSlotIndex;
    _slots = [
      const SlotAssignment(slotIndex: 0, contentType: SlotContentType.tasksList),
      const SlotAssignment(slotIndex: 1, contentType: SlotContentType.history),
      const SlotAssignment(slotIndex: 2, contentType: SlotContentType.empty),
    ];
    _updateMinimizedState();
  }

  // === PRESET APPLICATION ===

  /// Apply a named preset, replacing the current tree
  void applyPreset(String presetName) {
    final preset = LayoutPresets.byName(presetName);
    final result = preset.build();
    _root = result.tree;
    _nextSlotIndex = result.nextSlotIndex;

    // Resize slots to match new tree
    final newSlotCount = _root.leafCount;
    final newSlots = <SlotAssignment>[];

    for (int i = 0; i < newSlotCount; i++) {
      if (i < _slots.length) {
        newSlots.add(_slots[i].copyWith(slotIndex: i));
      } else {
        newSlots.add(SlotAssignment(slotIndex: i));
      }
    }
    _slots = newSlots;
    _updateMinimizedState();
    _core.notify();
    onLayoutChanged?.call();
  }

  // === SPLIT / CLOSE ===

  /// Split a leaf node in the given direction, creating a new pane
  void splitNode(String nodeId, SplitDirection direction) {
    final node = _root.findById(nodeId);
    if (node == null || !node.isLeaf) return;

    final newSlotIndex = _nextSlotIndex;
    node.split(direction, newSlotIndex);
    _nextSlotIndex++;

    // Add new slot assignment
    _slots.add(SlotAssignment(slotIndex: newSlotIndex));

    _core.notify();
    onLayoutChanged?.call();
  }

  /// Close a leaf node — minimizes its content before removing
  void closeNode(String nodeId) {
    // Don't allow closing the last pane
    if (_root.isLeaf) return;

    final node = _root.findById(nodeId);
    if (node == null || !node.isLeaf) return;

    // Mark content as minimized before removing
    final slot = _getSlotByIndex(node.slotIndex!);
    if (slot != null) {
      if (slot.isTasksList) _tasksListMinimized = true;
      if (slot.isHistory) _historyMinimized = true;
      if (slot.isResources) _resourcesMinimized = true;
    }

    // Find parent and remove the node
    if (_root.id == nodeId) return; // Can't close root (already guarded above)
    final parent = _root.findParent(nodeId);
    if (parent != null) {
      parent.removeChild(nodeId);
    }

    _core.notify();
    onLayoutChanged?.call();
  }

  // === FLEX / RESIZE ===

  /// Update flex ratios when dragging a divider between children of parentNodeId
  void updateFlex(String parentId, int dividerIndex, double delta, double totalSize) {
    final parent = _root.findById(parentId);
    if (parent == null || parent.isLeaf) return;
    if (dividerIndex < 0 || dividerIndex >= parent.children.length - 1) return;
    if (totalSize <= 0) return;

    final leftIdx = dividerIndex;
    final rightIdx = dividerIndex + 1;
    final leftChild = parent.children[leftIdx];
    final rightChild = parent.children[rightIdx];

    final totalFlex = parent.children.fold(0.0, (sum, c) => sum + c.flex);
    final deltaRatio = (delta / totalSize) * totalFlex;

    final minFlex = 0.1 * totalFlex;

    final newLeft = (leftChild.flex + deltaRatio).clamp(minFlex, totalFlex);
    final newRight = (rightChild.flex - deltaRatio).clamp(minFlex, totalFlex);

    if (newLeft >= minFlex && newRight >= minFlex) {
      leftChild.flex = newLeft;
      rightChild.flex = newRight;
      _core.notify();
    }
  }

  /// Notify that drag ended - trigger save
  void notifyDragEnd() {
    onLayoutChanged?.call();
  }

  // === SLOT MANAGEMENT ===

  /// Assign content to a slot
  void assignSlot(int slotIndex, SlotContentType type, [String? contentId]) {
    final idx = _slots.indexWhere((s) => s.slotIndex == slotIndex);
    if (idx < 0) return;

    // Check if we're replacing tasksList, history, or resources (they become minimized)
    final oldSlot = _slots[idx];
    if (oldSlot.isTasksList && type != SlotContentType.tasksList) {
      _tasksListMinimized = true;
    } else if (oldSlot.isHistory && type != SlotContentType.history) {
      _historyMinimized = true;
    } else if (oldSlot.isResources && type != SlotContentType.resources) {
      _resourcesMinimized = true;
    }

    // If assigning tasksList, history, or resources, they're no longer minimized
    if (type == SlotContentType.tasksList) _tasksListMinimized = false;
    if (type == SlotContentType.history) _historyMinimized = false;
    if (type == SlotContentType.resources) _resourcesMinimized = false;

    _slots[idx] = SlotAssignment(
      slotIndex: slotIndex,
      contentType: type,
      contentId: contentId,
    );
    _core.notify();
  }

  /// Assign a terminal (running task) to a slot
  void assignTerminal(int slotIndex, String taskId) {
    assignSlot(slotIndex, SlotContentType.terminal, taskId);
  }

  /// Clear a slot
  void clearSlot(int slotIndex) {
    assignSlot(slotIndex, SlotContentType.empty, null);
  }

  /// Get assignment for a slot
  SlotAssignment? getSlot(int slotIndex) {
    final match = _slots.where((s) => s.slotIndex == slotIndex);
    return match.isNotEmpty ? match.first : null;
  }

  /// Swap two slots
  void swapSlots(int slot1, int slot2) {
    final idx1 = _slots.indexWhere((s) => s.slotIndex == slot1);
    final idx2 = _slots.indexWhere((s) => s.slotIndex == slot2);
    if (idx1 < 0 || idx2 < 0) return;

    final temp = _slots[idx1];
    _slots[idx1] = _slots[idx2].copyWith(slotIndex: slot1);
    _slots[idx2] = temp.copyWith(slotIndex: slot2);
    _core.notify();
  }

  /// Maximize tasksList to a specific slot
  void maximizeTasksList(int slotIndex) {
    assignSlot(slotIndex, SlotContentType.tasksList);
  }

  /// Maximize history to a specific slot
  void maximizeHistory(int slotIndex) {
    assignSlot(slotIndex, SlotContentType.history);
  }

  /// Maximize resources to a specific slot
  void maximizeResources(int slotIndex) {
    assignSlot(slotIndex, SlotContentType.resources);
  }

  /// Get list of empty or available slots for target selection
  List<int> get availableSlots {
    final activeSlots = slots;
    return activeSlots
        .where((s) => s.isEmpty || s.isTerminal)
        .map((s) => s.slotIndex)
        .toList();
  }

  /// Find slot index by task ID
  int? findSlotByTaskId(String taskId) {
    for (final slot in slots) {
      if (slot.isTerminal && slot.contentId == taskId) {
        return slot.slotIndex;
      }
    }
    return null;
  }

  // === INTERNAL HELPERS ===

  SlotAssignment? _getSlotByIndex(int slotIndex) {
    final match = _slots.where((s) => s.slotIndex == slotIndex);
    return match.isNotEmpty ? match.first : null;
  }

  /// Update minimized state based on current active slots
  void _updateMinimizedState() {
    _tasksListMinimized = !isTasksListVisible;
    _historyMinimized = !isHistoryVisible;
    _resourcesMinimized = !isResourcesVisible;
  }

  // === PERSISTENCE ===

  /// Initialize layout from saved settings
  void initFromSettings(AppSettings settings) {
    // Try to load tree from JSON
    if (settings.layoutTree != null) {
      try {
        _root = LayoutNode.fromJson(settings.layoutTree!);
        _nextSlotIndex = settings.layoutNextSlotIndex;
      } catch (_) {
        // Fallback to default
        final result = LayoutPresets.threeColumns();
        _root = result.tree;
        _nextSlotIndex = result.nextSlotIndex;
      }
    } else {
      // Backward compatibility: migrate from old preset name
      final oldPresetName = settings.layoutTree == null
          ? (settings.toJson()['layoutPreset'] as String? ?? 'threeColumns')
          : 'threeColumns';
      final preset = LayoutPresets.byName(oldPresetName);
      final result = preset.build();
      _root = result.tree;
      _nextSlotIndex = result.nextSlotIndex;
    }

    // Load slot assignments
    if (settings.slotAssignments.isNotEmpty) {
      _slots = List.from(settings.slotAssignments);
    } else {
      _slots = [
        const SlotAssignment(slotIndex: 0, contentType: SlotContentType.tasksList),
        const SlotAssignment(slotIndex: 1, contentType: SlotContentType.history),
        const SlotAssignment(slotIndex: 2, contentType: SlotContentType.empty),
      ];
      // Ensure slots cover all leaf nodes
      final leafCount = _root.leafCount;
      while (_slots.length < leafCount) {
        _slots.add(SlotAssignment(slotIndex: _slots.length));
      }
    }

    // Startup reorganization
    _reorganizeStartupSlots();
    _updateMinimizedState();
    _core.notify();
  }

  /// Reorganize slots at startup: convert orphaned terminals to empty,
  /// fill empty slots with tasksList/history, and order left-to-right top-to-bottom
  void _reorganizeStartupSlots() {
    final activeIndices = _root.allSlotIndices.toSet();

    bool hasTasksList = _slots.any((s) => activeIndices.contains(s.slotIndex) && s.isTasksList);
    bool hasHistory = _slots.any((s) => activeIndices.contains(s.slotIndex) && s.isHistory);

    final organizedContent = <SlotContentType>[];

    if (hasTasksList) organizedContent.add(SlotContentType.tasksList);
    if (hasHistory) organizedContent.add(SlotContentType.history);

    int emptySlots = activeIndices.length - organizedContent.length;

    if (!hasTasksList && emptySlots > 0) {
      organizedContent.insert(0, SlotContentType.tasksList);
      emptySlots--;
    }

    if (!hasHistory && emptySlots > 0) {
      final insertIndex = organizedContent.contains(SlotContentType.tasksList) ? 1 : 0;
      organizedContent.insert(insertIndex, SlotContentType.history);
      emptySlots--;
    }

    while (organizedContent.length < activeIndices.length) {
      organizedContent.add(SlotContentType.empty);
    }

    // Rebuild slots for active indices in tree order
    final orderedIndices = _root.allSlotIndices;
    final newSlots = <SlotAssignment>[];
    for (int i = 0; i < orderedIndices.length && i < organizedContent.length; i++) {
      newSlots.add(SlotAssignment(
        slotIndex: orderedIndices[i],
        contentType: organizedContent[i],
      ));
    }

    // Keep any non-active slots for later use
    for (final slot in _slots) {
      if (!activeIndices.contains(slot.slotIndex)) {
        newSlots.add(slot);
      }
    }

    _slots = newSlots;
  }

  /// Export current state for saving to settings
  ({
    Map<String, dynamic> tree,
    int nextSlotIndex,
    List<SlotAssignment> slots,
  }) exportForSettings() {
    return (
      tree: _root.toJson(),
      nextSlotIndex: _nextSlotIndex,
      slots: List.from(_slots),
    );
  }
}
