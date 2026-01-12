import '../models/app_settings.dart';
import '../models/layout_preset.dart';
import '../models/layout_sizes.dart';
import '../models/slot_assignment.dart';
import 'core.dart';

/// Extension managing layout state
class LayoutExtension {
  final Core _core;

  LayoutExtension(this._core) {
    // Initialize with default layout
    _initDefaultLayout();
  }

  LayoutPreset _currentPreset = LayoutPreset.threeColumns;
  List<SlotAssignment> _slots = [];

  // Track if tasksList/history are minimized (not visible in any slot)
  bool _tasksListMinimized = false;
  bool _historyMinimized = false;

  // Flex ratio management for resizable panes
  LayoutSizes _currentSizes = LayoutSizes.defaults(LayoutPreset.threeColumns);
  Map<String, LayoutSizes> _allPaneSizes = {};

  // Callback to trigger settings save (set by SettingsExtension)
  void Function()? onLayoutChanged;

  /// Get available layout options for dropdown
  List<LayoutPreset> layoutOptions() {
    return LayoutPreset.values;
  }

  /// Get current layout preset
  LayoutPreset get currentPreset => _currentPreset;

  /// Get current slot assignments
  List<SlotAssignment> get slots => List.unmodifiable(_slots);

  /// Get slot count for current layout
  int get slotCount => _currentPreset.slotCount;

  /// Check if tasksList is minimized
  bool get isTasksListMinimized => _tasksListMinimized;

  /// Check if history is minimized
  bool get isHistoryMinimized => _historyMinimized;

  /// Check if tasksList is visible in any slot
  bool get isTasksListVisible => _slots.any((s) => s.isTasksList);

  /// Check if history is visible in any slot
  bool get isHistoryVisible => _slots.any((s) => s.isHistory);

  /// Get current layout sizes
  LayoutSizes get currentSizes => _currentSizes;

  /// Get all pane sizes map (for persistence)
  Map<String, LayoutSizes> get allPaneSizes => Map.unmodifiable(_allPaneSizes);

  /// Get flex ratio for main axis at given index (multiplied by 100 for int flex)
  int getMainFlex(int index) {
    if (index < 0 || index >= _currentSizes.mainRatios.length) return 100;
    return (_currentSizes.mainRatios[index] * 100).round();
  }

  /// Get flex ratio for nested1 at given index
  int getNested1Flex(int index) {
    final ratios = _currentSizes.nestedRatios1;
    if (ratios == null || index < 0 || index >= ratios.length) return 100;
    return (ratios[index] * 100).round();
  }

  /// Get flex ratio for nested2 at given index
  int getNested2Flex(int index) {
    final ratios = _currentSizes.nestedRatios2;
    if (ratios == null || index < 0 || index >= ratios.length) return 100;
    return (ratios[index] * 100).round();
  }

  /// Initialize default layout with tasksList, history, and an empty terminal slot
  void _initDefaultLayout() {
    _currentPreset = LayoutPreset.threeColumns;
    _slots = [
      const SlotAssignment(slotIndex: 0, contentType: SlotContentType.tasksList),
      const SlotAssignment(slotIndex: 1, contentType: SlotContentType.history),
      const SlotAssignment(slotIndex: 2, contentType: SlotContentType.empty),
    ];
    _currentSizes = LayoutSizes.defaults(_currentPreset);
    _updateMinimizedState();
  }

  /// Set layout preset
  void setLayout(LayoutPreset preset) {
    if (_currentPreset == preset) return;
    _setPreset(preset);
    _core.notify();
    onLayoutChanged?.call();
  }

  void _setPreset(LayoutPreset preset) {
    // Save current sizes before switching
    _allPaneSizes[_currentPreset.name] = _currentSizes;

    _currentPreset = preset;

    // Load sizes for new preset (or use defaults)
    _currentSizes =
        _allPaneSizes[preset.name] ?? LayoutSizes.defaults(preset);

    // Resize slots array to match new layout
    final newSlotCount = preset.slotCount;
    final newSlots = <SlotAssignment>[];

    for (int i = 0; i < newSlotCount; i++) {
      if (i < _slots.length) {
        // Keep existing assignment
        newSlots.add(_slots[i].copyWith(slotIndex: i));
      } else {
        // Create empty slot
        newSlots.add(SlotAssignment(slotIndex: i));
      }
    }
    _slots = newSlots;
    _updateMinimizedState();
  }

  /// Update minimized state based on current slots
  void _updateMinimizedState() {
    _tasksListMinimized = !isTasksListVisible;
    _historyMinimized = !isHistoryVisible;
  }

  /// Assign content to a slot
  void assignSlot(int slotIndex, SlotContentType type, [String? contentId]) {
    if (slotIndex < 0 || slotIndex >= _slots.length) return;

    // Check if we're replacing tasksList or history (they become minimized)
    final oldSlot = _slots[slotIndex];
    if (oldSlot.isTasksList && type != SlotContentType.tasksList) {
      _tasksListMinimized = true;
    } else if (oldSlot.isHistory && type != SlotContentType.history) {
      _historyMinimized = true;
    }

    // If assigning tasksList or history, they're no longer minimized
    if (type == SlotContentType.tasksList) {
      _tasksListMinimized = false;
    } else if (type == SlotContentType.history) {
      _historyMinimized = false;
    }

    _slots[slotIndex] = SlotAssignment(
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
    if (slotIndex < 0 || slotIndex >= _slots.length) return null;
    return _slots[slotIndex];
  }

  /// Swap two slots
  void swapSlots(int slot1, int slot2) {
    if (slot1 < 0 || slot1 >= _slots.length) return;
    if (slot2 < 0 || slot2 >= _slots.length) return;

    final temp = _slots[slot1];
    _slots[slot1] = _slots[slot2].copyWith(slotIndex: slot1);
    _slots[slot2] = temp.copyWith(slotIndex: slot2);
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

  /// Get list of empty or available slots for target selection
  List<int> get availableSlots {
    return _slots
        .where((s) => s.isEmpty || s.isTerminal)
        .map((s) => s.slotIndex)
        .toList();
  }

  /// Find slot index by task ID
  int? findSlotByTaskId(String taskId) {
    for (final slot in _slots) {
      if (slot.isTerminal && slot.contentId == taskId) {
        return slot.slotIndex;
      }
    }
    return null;
  }

  // === FLEX RATIO MANAGEMENT ===

  /// Update main axis flex ratios when dragging a divider
  /// [dividerIndex] is the index of the divider (0 = between pane 0-1)
  /// [pixelDelta] is the drag delta in pixels
  /// [totalSize] is the total size of the container
  void updateMainRatios(int dividerIndex, double pixelDelta, double totalSize) {
    _updateRatios(
      _currentSizes.mainRatios,
      dividerIndex,
      pixelDelta,
      totalSize,
      (newRatios) => _currentSizes = _currentSizes.copyWith(mainRatios: newRatios),
    );
  }

  /// Update nested1 flex ratios
  void updateNested1Ratios(
      int dividerIndex, double pixelDelta, double totalSize) {
    final ratios = _currentSizes.nestedRatios1;
    if (ratios == null) return;
    _updateRatios(
      ratios,
      dividerIndex,
      pixelDelta,
      totalSize,
      (newRatios) =>
          _currentSizes = _currentSizes.copyWith(nestedRatios1: newRatios),
    );
  }

  /// Update nested2 flex ratios
  void updateNested2Ratios(
      int dividerIndex, double pixelDelta, double totalSize) {
    final ratios = _currentSizes.nestedRatios2;
    if (ratios == null) return;
    _updateRatios(
      ratios,
      dividerIndex,
      pixelDelta,
      totalSize,
      (newRatios) =>
          _currentSizes = _currentSizes.copyWith(nestedRatios2: newRatios),
    );
  }

  void _updateRatios(
    List<double> ratios,
    int dividerIndex,
    double pixelDelta,
    double totalSize,
    void Function(List<double>) updateCallback,
  ) {
    if (dividerIndex < 0 || dividerIndex >= ratios.length - 1) return;
    if (totalSize <= 0) return;

    final leftIdx = dividerIndex;
    final rightIdx = dividerIndex + 1;

    // Convert pixel delta to ratio delta
    final totalFlex = ratios.reduce((a, b) => a + b);
    final deltaRatio = (pixelDelta / totalSize) * totalFlex;

    // Create new ratios list
    final newRatios = List<double>.from(ratios);

    // Minimum 20% of total (0.2 * totalFlex ensures true 20% minimum)
    final minFlex = 0.2 * totalFlex;
    final maxFlex = totalFlex - (minFlex * (ratios.length - 1));

    final newLeft = (newRatios[leftIdx] + deltaRatio).clamp(minFlex, maxFlex);
    final newRight = (newRatios[rightIdx] - deltaRatio).clamp(minFlex, maxFlex);

    // Only update if both values are valid
    if (newLeft >= minFlex && newRight >= minFlex) {
      newRatios[leftIdx] = newLeft;
      newRatios[rightIdx] = newRight;
      updateCallback(newRatios);
      _core.notify();
    }
  }

  /// Notify that drag ended - trigger save
  void notifyDragEnd() {
    // Save current sizes to the map
    _allPaneSizes[_currentPreset.name] = _currentSizes;
    onLayoutChanged?.call();
  }

  // === PERSISTENCE ===

  /// Initialize layout from saved settings
  void initFromSettings(AppSettings settings) {
    // Load pane sizes
    _allPaneSizes = Map.from(settings.paneSizes);

    // Set preset
    _currentPreset = settings.layoutPreset;

    // Load sizes for current preset
    _currentSizes =
        _allPaneSizes[_currentPreset.name] ?? LayoutSizes.defaults(_currentPreset);

    // Load slot assignments (or use defaults if empty)
    if (settings.slotAssignments.isNotEmpty) {
      _slots = List.from(settings.slotAssignments);
    } else {
      // Keep default assignments
      _slots = [
        const SlotAssignment(
            slotIndex: 0, contentType: SlotContentType.tasksList),
        const SlotAssignment(slotIndex: 1, contentType: SlotContentType.history),
        const SlotAssignment(slotIndex: 2, contentType: SlotContentType.empty),
      ];
      // Adjust to match preset slot count
      while (_slots.length < _currentPreset.slotCount) {
        _slots.add(SlotAssignment(slotIndex: _slots.length));
      }
      if (_slots.length > _currentPreset.slotCount) {
        _slots = _slots.sublist(0, _currentPreset.slotCount);
      }
    }

    _updateMinimizedState();
    _core.notify();
  }

  /// Export current state for saving to settings
  ({
    LayoutPreset preset,
    List<SlotAssignment> slots,
    Map<String, LayoutSizes> sizes
  }) exportForSettings() {
    // Make sure current sizes are saved
    _allPaneSizes[_currentPreset.name] = _currentSizes;

    return (
      preset: _currentPreset,
      slots: List.from(_slots),
      sizes: Map.from(_allPaneSizes),
    );
  }
}
