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
  fourGrid;

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
  };

  static LayoutPreset fromName(String name) {
    return LayoutPreset.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LayoutPreset.threeColumns,
    );
  }
}
