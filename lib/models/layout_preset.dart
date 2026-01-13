import 'package:flutter/material.dart';

/// Predefined layout configurations
enum LayoutPreset {
  single,
  twoColumns,
  twoRows,
  threeColumns,
  threeRows,
  twoLeftOneRight,
  oneLeftTwoRight,
  twoTopOneBottom,
  oneTopTwoBottom,
  fourGrid,
  fourRows,
  fourColumns,
  threeLeftOneRight,
  oneLeftThreeRight,
  threeTopOneBottom,
  oneTopThreeBottom,
  twoLeftThreeRight,
  threeLeftThreeRight,
  oneTopTwoLeftThreeRight,
  oneTopFourGrid;

  String get displayName => switch (this) {
    LayoutPreset.single => '1 Pane',
    LayoutPreset.twoColumns => '2 Columns',
    LayoutPreset.twoRows => '2 Rows',
    LayoutPreset.threeColumns => '3 Columns',
    LayoutPreset.threeRows => '3 Rows',
    LayoutPreset.twoLeftOneRight => '2 Left + 1 Right',
    LayoutPreset.oneLeftTwoRight => '1 Left + 2 Right',
    LayoutPreset.twoTopOneBottom => '2 Top + 1 Bottom',
    LayoutPreset.oneTopTwoBottom => '1 Top + 2 Bottom',
    LayoutPreset.fourGrid => '2x2 Grid',
    LayoutPreset.fourRows => '4 Rows',
    LayoutPreset.fourColumns => '4 Columns',
    LayoutPreset.threeLeftOneRight => '3 Left + 1 Right',
    LayoutPreset.oneLeftThreeRight => '1 Left + 3 Right',
    LayoutPreset.threeTopOneBottom => '3 Top + 1 Bottom',
    LayoutPreset.oneTopThreeBottom => '1 Top + 3 Bottom',
    LayoutPreset.twoLeftThreeRight => '2 Left + 3 Right',
    LayoutPreset.threeLeftThreeRight => '3 Left + 3 Right',
    LayoutPreset.oneTopTwoLeftThreeRight => '1 Top + 2L/3R',
    LayoutPreset.oneTopFourGrid => '1 Top + 2x2',
  };

  int get slotCount => switch (this) {
    LayoutPreset.single => 1,
    LayoutPreset.twoColumns => 2,
    LayoutPreset.twoRows => 2,
    LayoutPreset.threeColumns => 3,
    LayoutPreset.threeRows => 3,
    LayoutPreset.twoLeftOneRight => 3,
    LayoutPreset.oneLeftTwoRight => 3,
    LayoutPreset.twoTopOneBottom => 3,
    LayoutPreset.oneTopTwoBottom => 3,
    LayoutPreset.fourGrid => 4,
    LayoutPreset.fourRows => 4,
    LayoutPreset.fourColumns => 4,
    LayoutPreset.threeLeftOneRight => 4,
    LayoutPreset.oneLeftThreeRight => 4,
    LayoutPreset.threeTopOneBottom => 4,
    LayoutPreset.oneTopThreeBottom => 4,
    LayoutPreset.twoLeftThreeRight => 5,
    LayoutPreset.threeLeftThreeRight => 6,
    LayoutPreset.oneTopTwoLeftThreeRight => 6,
    LayoutPreset.oneTopFourGrid => 5,
  };

  IconData get icon => switch (this) {
    LayoutPreset.single => Icons.square_outlined,
    LayoutPreset.twoColumns => Icons.view_column,
    LayoutPreset.twoRows => Icons.view_agenda,
    LayoutPreset.threeColumns => Icons.view_week,
    LayoutPreset.threeRows => Icons.table_rows,
    LayoutPreset.twoLeftOneRight => Icons.view_sidebar,
    LayoutPreset.oneLeftTwoRight => Icons.view_sidebar_outlined,
    LayoutPreset.twoTopOneBottom => Icons.view_stream,
    LayoutPreset.oneTopTwoBottom => Icons.view_module,
    LayoutPreset.fourGrid => Icons.grid_view,
    LayoutPreset.fourRows => Icons.table_rows_outlined,
    LayoutPreset.fourColumns => Icons.view_week_outlined,
    LayoutPreset.threeLeftOneRight => Icons.vertical_split,
    LayoutPreset.oneLeftThreeRight => Icons.vertical_split_outlined,
    LayoutPreset.threeTopOneBottom => Icons.horizontal_split,
    LayoutPreset.oneTopThreeBottom => Icons.horizontal_split_outlined,
    LayoutPreset.twoLeftThreeRight => Icons.view_column_outlined,
    LayoutPreset.threeLeftThreeRight => Icons.calendar_view_month,
    LayoutPreset.oneTopTwoLeftThreeRight => Icons.dashboard,
    LayoutPreset.oneTopFourGrid => Icons.dashboard_outlined,
  };

  static LayoutPreset fromName(String name) {
    return LayoutPreset.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LayoutPreset.threeColumns,
    );
  }
}
