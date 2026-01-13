import 'package:flutter/material.dart';
import '../core/core.dart';

/// Controller for pane drag-and-drop operations
class PaneDragController extends ChangeNotifier {
  static final PaneDragController instance = PaneDragController._();
  PaneDragController._();

  // Drag state
  bool _isDragging = false;
  int? _sourceSlotIndex;
  int? _currentTargetIndex;
  Offset _dragPosition = Offset.zero;

  // Pane position registry
  final Map<int, GlobalKey> _paneKeys = {};
  final Map<int, Rect> _paneRects = {};

  // Animation state - stores the animated offsets for each pane
  final Map<int, Offset> _animatedOffsets = {};

  bool get isDragging => _isDragging;
  int? get sourceSlotIndex => _sourceSlotIndex;
  int? get currentTargetIndex => _currentTargetIndex;
  Offset get dragPosition => _dragPosition;

  void registerPane(int slotIndex, GlobalKey key) {
    _paneKeys[slotIndex] = key;
  }

  void unregisterPane(int slotIndex) {
    _paneKeys.remove(slotIndex);
    _paneRects.remove(slotIndex);
    _animatedOffsets.remove(slotIndex);
  }

  void _updatePaneRects() {
    _paneRects.clear();
    for (final entry in _paneKeys.entries) {
      final context = entry.value.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          final position = box.localToGlobal(Offset.zero);
          _paneRects[entry.key] = Rect.fromLTWH(
            position.dx,
            position.dy,
            box.size.width,
            box.size.height,
          );
        }
      }
    }
  }

  Rect? getPaneRect(int slotIndex) => _paneRects[slotIndex];

  /// Get the animated offset for a pane (used during drag)
  Offset getAnimatedOffset(int slotIndex) => _animatedOffsets[slotIndex] ?? Offset.zero;

  void startDrag(int slotIndex, Offset globalPosition) {
    _isDragging = true;
    _sourceSlotIndex = slotIndex;
    _currentTargetIndex = null;
    _dragPosition = globalPosition;
    _animatedOffsets.clear();
    _updatePaneRects();
    notifyListeners();
  }

  void updateDrag(Offset globalPosition) {
    if (!_isDragging) return;
    _dragPosition = globalPosition;

    // Find which pane we're hovering over
    int? newTarget;
    for (final entry in _paneRects.entries) {
      if (entry.key != _sourceSlotIndex && entry.value.contains(globalPosition)) {
        newTarget = entry.key;
        break;
      }
    }

    if (newTarget != _currentTargetIndex) {
      _currentTargetIndex = newTarget;
      _updateAnimatedOffsets();
    }

    notifyListeners();
  }

  void _updateAnimatedOffsets() {
    _animatedOffsets.clear();

    if (_sourceSlotIndex != null && _currentTargetIndex != null) {
      final sourceRect = _paneRects[_sourceSlotIndex];
      final targetRect = _paneRects[_currentTargetIndex];

      if (sourceRect != null && targetRect != null) {
        // Calculate offset to swap positions
        final deltaX = targetRect.left - sourceRect.left;
        final deltaY = targetRect.top - sourceRect.top;

        // Source moves to target position
        _animatedOffsets[_sourceSlotIndex!] = Offset(deltaX, deltaY);
        // Target moves to source position
        _animatedOffsets[_currentTargetIndex!] = Offset(-deltaX, -deltaY);
      }
    }
  }

  void endDrag({bool didDrop = false}) {
    final source = _sourceSlotIndex;
    final target = _currentTargetIndex;
    final shouldSwap = didDrop && source != null && target != null;

    // Clear all state before any notifications
    _animatedOffsets.clear();
    _isDragging = false;
    _sourceSlotIndex = null;
    _currentTargetIndex = null;

    if (shouldSwap) {
      // swapSlots triggers core.notify() which rebuilds panes
      // Panes listen to both core and this controller via Listenable.merge
      // so they'll see our cleared state when they rebuild
      core.layout.swapSlots(source, target);
    } else {
      // No swap - just notify to clear the offset transforms
      notifyListeners();
    }
  }
}

/// Wrapper that makes a pane header draggable
class DraggablePaneHeader extends StatefulWidget {
  final int slotIndex;
  final Widget child;

  const DraggablePaneHeader({
    super.key,
    required this.slotIndex,
    required this.child,
  });

  @override
  State<DraggablePaneHeader> createState() => _DraggablePaneHeaderState();
}

class _DraggablePaneHeaderState extends State<DraggablePaneHeader> {
  final _controller = PaneDragController.instance;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        setState(() => _isDragging = true);
        _controller.startDrag(widget.slotIndex, details.globalPosition);
      },
      onPanUpdate: (details) {
        _controller.updateDrag(details.globalPosition);
      },
      onPanEnd: (details) {
        setState(() => _isDragging = false);
        final hasTarget = _controller.currentTargetIndex != null;
        _controller.endDrag(didDrop: hasTarget);
      },
      onPanCancel: () {
        setState(() => _isDragging = false);
        _controller.endDrag(didDrop: false);
      },
      child: MouseRegion(
        cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: widget.child,
      ),
    );
  }
}
