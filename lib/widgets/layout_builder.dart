import 'package:flutter/material.dart';
import '../core/core.dart';
import '../models/layout_preset.dart';
import 'layout_pane.dart';
import 'resizable_divider.dart';

/// Builds the layout grid based on current preset
class PaneLayoutBuilder extends StatelessWidget {
  const PaneLayoutBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: core,
      builder: (context, _) {
        final preset = core.layout.currentPreset;
        return _LayoutContent(preset: preset);
      },
    );
  }
}

class _LayoutContent extends StatelessWidget {
  final LayoutPreset preset;

  const _LayoutContent({required this.preset});

  @override
  Widget build(BuildContext context) {
    return switch (preset) {
      LayoutPreset.single => _pane(0),

      LayoutPreset.twoColumns => Row(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(1)),
          ],
        ),

      LayoutPreset.twoRows => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(1)),
          ],
        ),

      LayoutPreset.threeColumns => Row(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(1)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 1,
            ),
            Expanded(flex: core.layout.getMainFlex(2), child: _pane(2)),
          ],
        ),

      LayoutPreset.threeRows => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(1)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 1,
            ),
            Expanded(flex: core.layout.getMainFlex(2), child: _pane(2)),
          ],
        ),

      // Two panes stacked on left, one on right
      // main: [leftColumn, rightPane], nested1: [pane0, pane1]
      LayoutPreset.twoLeftOneRight => Row(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(2)),
          ],
        ),

      // One pane on left, two stacked on right
      // main: [leftPane, rightColumn], nested1: [pane1, pane2]
      LayoutPreset.oneLeftTwoRight => Row(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(2)),
                ],
              ),
            ),
          ],
        ),

      // Two panes side by side on top, one on bottom
      // main: [topRow, bottomPane], nested1: [pane0, pane1]
      LayoutPreset.twoTopOneBottom => Column(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Row(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(2)),
          ],
        ),

      // One pane on top, two side by side on bottom
      // main: [topPane, bottomRow], nested1: [pane1, pane2]
      LayoutPreset.oneTopTwoBottom => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Row(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(2)),
                ],
              ),
            ),
          ],
        ),

      // 2x2 grid
      // main: [topRow, bottomRow], nested1: [pane0, pane1], nested2: [pane2, pane3]
      LayoutPreset.fourGrid => Column(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Row(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Row(
                children: [
                  Expanded(flex: core.layout.getNested2Flex(0), child: _pane(2)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested2,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested2Flex(1), child: _pane(3)),
                ],
              ),
            ),
          ],
        ),

      // 4 rows stacked vertically
      LayoutPreset.fourRows => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(1)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 1,
            ),
            Expanded(flex: core.layout.getMainFlex(2), child: _pane(2)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 2,
            ),
            Expanded(flex: core.layout.getMainFlex(3), child: _pane(3)),
          ],
        ),

      // 4 columns side by side
      LayoutPreset.fourColumns => Row(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(1)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 1,
            ),
            Expanded(flex: core.layout.getMainFlex(2), child: _pane(2)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 2,
            ),
            Expanded(flex: core.layout.getMainFlex(3), child: _pane(3)),
          ],
        ),

      // Three panes stacked on left, one on right
      // main: [leftColumn, rightPane], nested1: [pane0, pane1, pane2]
      LayoutPreset.threeLeftOneRight => Row(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(2), child: _pane(2)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(3)),
          ],
        ),

      // One pane on left, three stacked on right
      // main: [leftPane, rightColumn], nested1: [pane1, pane2, pane3]
      LayoutPreset.oneLeftThreeRight => Row(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(2)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(2), child: _pane(3)),
                ],
              ),
            ),
          ],
        ),

      // Three panes side by side on top, one on bottom
      // main: [topRow, bottomPane], nested1: [pane0, pane1, pane2]
      LayoutPreset.threeTopOneBottom => Column(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Row(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(2), child: _pane(2)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(flex: core.layout.getMainFlex(1), child: _pane(3)),
          ],
        ),

      // One pane on top, three side by side on bottom
      // main: [topPane, bottomRow], nested1: [pane1, pane2, pane3]
      LayoutPreset.oneTopThreeBottom => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Row(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(2)),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(2), child: _pane(3)),
                ],
              ),
            ),
          ],
        ),

      // Two panes stacked on left, three stacked on right
      // main: [leftColumn, rightColumn], nested1: [pane0, pane1], nested2: [pane2, pane3, pane4]
      LayoutPreset.twoLeftThreeRight => Row(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested2Flex(0), child: _pane(2)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested2,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested2Flex(1), child: _pane(3)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested2,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested2Flex(2), child: _pane(4)),
                ],
              ),
            ),
          ],
        ),

      // Three panes stacked on left, three stacked on right
      // main: [leftColumn, rightColumn], nested1: [pane0, pane1, pane2], nested2: [pane3, pane4, pane5]
      LayoutPreset.threeLeftThreeRight => Row(
          children: [
            Expanded(
              flex: core.layout.getMainFlex(0),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested1Flex(0), child: _pane(0)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(1), child: _pane(1)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested1Flex(2), child: _pane(2)),
                ],
              ),
            ),
            const ResizableDivider(
              axis: Axis.vertical,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Column(
                children: [
                  Expanded(flex: core.layout.getNested2Flex(0), child: _pane(3)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested2,
                    dividerIndex: 0,
                  ),
                  Expanded(flex: core.layout.getNested2Flex(1), child: _pane(4)),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested2,
                    dividerIndex: 1,
                  ),
                  Expanded(flex: core.layout.getNested2Flex(2), child: _pane(5)),
                ],
              ),
            ),
          ],
        ),

      // 1 pane on top, then 2 left + 3 right below
      // main: [topPane, bottomSection], nested1: [leftCol, rightCol], nested2: [right0, right1, right2]
      LayoutPreset.oneTopTwoLeftThreeRight => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Row(
                children: [
                  // Left column: 2 panes stacked
                  Expanded(
                    flex: core.layout.getNested1Flex(0),
                    child: Column(
                      children: [
                        Expanded(child: _pane(1)),
                        const ResizableDivider(
                          axis: Axis.horizontal,
                          ratioGroup: RatioGroup.nested1,
                          dividerIndex: 0,
                        ),
                        Expanded(child: _pane(2)),
                      ],
                    ),
                  ),
                  const ResizableDivider(
                    axis: Axis.vertical,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  // Right column: 3 panes stacked
                  Expanded(
                    flex: core.layout.getNested1Flex(1),
                    child: Column(
                      children: [
                        Expanded(flex: core.layout.getNested2Flex(0), child: _pane(3)),
                        const ResizableDivider(
                          axis: Axis.horizontal,
                          ratioGroup: RatioGroup.nested2,
                          dividerIndex: 0,
                        ),
                        Expanded(flex: core.layout.getNested2Flex(1), child: _pane(4)),
                        const ResizableDivider(
                          axis: Axis.horizontal,
                          ratioGroup: RatioGroup.nested2,
                          dividerIndex: 1,
                        ),
                        Expanded(flex: core.layout.getNested2Flex(2), child: _pane(5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

      // 1 pane on top, then 2x2 grid below
      // main: [topPane, bottomGrid], nested1: [topRow, bottomRow], nested2: [left, right] for each row
      LayoutPreset.oneTopFourGrid => Column(
          children: [
            Expanded(flex: core.layout.getMainFlex(0), child: _pane(0)),
            const ResizableDivider(
              axis: Axis.horizontal,
              ratioGroup: RatioGroup.main,
              dividerIndex: 0,
            ),
            Expanded(
              flex: core.layout.getMainFlex(1),
              child: Column(
                children: [
                  // Top row of grid
                  Expanded(
                    flex: core.layout.getNested1Flex(0),
                    child: Row(
                      children: [
                        Expanded(flex: core.layout.getNested2Flex(0), child: _pane(1)),
                        const ResizableDivider(
                          axis: Axis.vertical,
                          ratioGroup: RatioGroup.nested2,
                          dividerIndex: 0,
                        ),
                        Expanded(flex: core.layout.getNested2Flex(1), child: _pane(2)),
                      ],
                    ),
                  ),
                  const ResizableDivider(
                    axis: Axis.horizontal,
                    ratioGroup: RatioGroup.nested1,
                    dividerIndex: 0,
                  ),
                  // Bottom row of grid
                  Expanded(
                    flex: core.layout.getNested1Flex(1),
                    child: Row(
                      children: [
                        Expanded(flex: core.layout.getNested2Flex(0), child: _pane(3)),
                        const ResizableDivider(
                          axis: Axis.vertical,
                          ratioGroup: RatioGroup.nested2,
                          dividerIndex: 0,
                        ),
                        Expanded(flex: core.layout.getNested2Flex(1), child: _pane(4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    };
  }

  Widget _pane(int index) {
    return LayoutPane(slotIndex: index);
  }
}
