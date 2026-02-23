import 'package:flutter/material.dart';
import 'models/layout_node.dart';
import 'state/layout_state.dart';
import 'widgets/layout_tree.dart';

void main() {
  runApp(const PaneResearchApp());
}

class PaneResearchApp extends StatelessWidget {
  const PaneResearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pane Layout Research',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0d0d0d),
      ),
      home: const LayoutPlayground(),
    );
  }
}

class LayoutPlayground extends StatefulWidget {
  const LayoutPlayground({super.key});

  @override
  State<LayoutPlayground> createState() => _LayoutPlaygroundState();
}

class _LayoutPlaygroundState extends State<LayoutPlayground> {
  final _layoutState = LayoutState();

  @override
  void initState() {
    super.initState();
    _layoutState.addListener(_onLayoutChange);
  }

  @override
  void dispose() {
    _layoutState.removeListener(_onLayoutChange);
    _layoutState.dispose();
    super.dispose();
  }

  void _onLayoutChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutTree(
                node: _layoutState.root,
                state: _layoutState,
              ),
            ),
          ),
          _buildInfoBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Pane Layout Research',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 24),
          _ToolbarButton(
            label: 'Reset',
            icon: Icons.refresh,
            onPressed: () => _layoutState.reset(),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            label: '2 Columns',
            icon: Icons.view_column,
            onPressed: () => _applyPreset2Cols(),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            label: '2 Rows',
            icon: Icons.view_agenda,
            onPressed: () => _applyPreset2Rows(),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            label: '2x2 Grid',
            icon: Icons.grid_view,
            onPressed: () => _applyPreset2x2(),
          ),
          const Spacer(),
          Text(
            'Hover a pane to split or close',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar() {
    final root = _layoutState.root;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Panes: ${root.leafCount}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Slots: ${root.allSlotIndices.join(", ")}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Tree: $root',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyPreset2Cols() {
    _layoutState.applyPreset(
      LayoutNode.split(
        direction: SplitDirection.row,
        children: [
          LayoutNode.leaf(slotIndex: 0),
          LayoutNode.leaf(slotIndex: 1),
        ],
      ),
      2,
    );
  }

  void _applyPreset2Rows() {
    _layoutState.applyPreset(
      LayoutNode.split(
        direction: SplitDirection.column,
        children: [
          LayoutNode.leaf(slotIndex: 0),
          LayoutNode.leaf(slotIndex: 1),
        ],
      ),
      2,
    );
  }

  void _applyPreset2x2() {
    _layoutState.applyPreset(
      LayoutNode.split(
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
      4,
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hovering
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovering ? 0.15 : 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
