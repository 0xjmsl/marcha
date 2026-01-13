import 'package:collection/collection.dart';
import 'layout_preset.dart';

/// Stores flex ratios for a layout's divider groups
class LayoutSizes {
  final List<double> mainRatios;
  final List<double>? nestedRatios1;
  final List<double>? nestedRatios2;

  const LayoutSizes({
    required this.mainRatios,
    this.nestedRatios1,
    this.nestedRatios2,
  });

  factory LayoutSizes.defaults(LayoutPreset preset) {
    return switch (preset) {
      LayoutPreset.single => const LayoutSizes(mainRatios: [1.0]),
      LayoutPreset.twoColumns => const LayoutSizes(mainRatios: [1.0, 1.0]),
      LayoutPreset.twoRows => const LayoutSizes(mainRatios: [1.0, 1.0]),
      LayoutPreset.threeColumns =>
        const LayoutSizes(mainRatios: [1.0, 1.0, 1.0]),
      LayoutPreset.threeRows => const LayoutSizes(mainRatios: [1.0, 1.0, 1.0]),
      LayoutPreset.twoLeftOneRight => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0],
        ),
      LayoutPreset.oneLeftTwoRight => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0],
        ),
      LayoutPreset.twoTopOneBottom => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0],
        ),
      LayoutPreset.oneTopTwoBottom => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0],
        ),
      LayoutPreset.fourGrid => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0],
          nestedRatios2: [1.0, 1.0],
        ),
      LayoutPreset.fourRows =>
        const LayoutSizes(mainRatios: [1.0, 1.0, 1.0, 1.0]),
      LayoutPreset.fourColumns =>
        const LayoutSizes(mainRatios: [1.0, 1.0, 1.0, 1.0]),
      LayoutPreset.threeLeftOneRight => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0, 1.0],
        ),
      LayoutPreset.oneLeftThreeRight => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0, 1.0],
        ),
      LayoutPreset.threeTopOneBottom => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0, 1.0],
        ),
      LayoutPreset.oneTopThreeBottom => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0, 1.0],
        ),
      LayoutPreset.twoLeftThreeRight => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0],
          nestedRatios2: [1.0, 1.0, 1.0],
        ),
      LayoutPreset.threeLeftThreeRight => const LayoutSizes(
          mainRatios: [1.0, 1.0],
          nestedRatios1: [1.0, 1.0, 1.0],
          nestedRatios2: [1.0, 1.0, 1.0],
        ),
      // 1 top row, then 2 left + 3 right below
      // main: [topRow, bottomSection], nested1: [leftCol, rightCol], nested2: [left0, left1], nested3 would be needed but we reuse nested2 pattern
      LayoutPreset.oneTopTwoLeftThreeRight => const LayoutSizes(
          mainRatios: [1.0, 2.0],
          nestedRatios1: [1.0, 1.0],
          nestedRatios2: [1.0, 1.0, 1.0],
        ),
      // 1 top row, then 2x2 grid below
      LayoutPreset.oneTopFourGrid => const LayoutSizes(
          mainRatios: [1.0, 2.0],
          nestedRatios1: [1.0, 1.0],
          nestedRatios2: [1.0, 1.0],
        ),
    };
  }

  LayoutSizes copyWith({
    List<double>? mainRatios,
    List<double>? nestedRatios1,
    List<double>? nestedRatios2,
  }) {
    return LayoutSizes(
      mainRatios: mainRatios ?? this.mainRatios,
      nestedRatios1: nestedRatios1 ?? this.nestedRatios1,
      nestedRatios2: nestedRatios2 ?? this.nestedRatios2,
    );
  }

  Map<String, dynamic> toJson() => {
        'mainRatios': mainRatios,
        if (nestedRatios1 != null) 'nestedRatios1': nestedRatios1,
        if (nestedRatios2 != null) 'nestedRatios2': nestedRatios2,
      };

  factory LayoutSizes.fromJson(Map<String, dynamic> json) => LayoutSizes(
        mainRatios: (json['mainRatios'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList(),
        nestedRatios1: (json['nestedRatios1'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
        nestedRatios2: (json['nestedRatios2'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayoutSizes &&
          runtimeType == other.runtimeType &&
          const ListEquality().equals(mainRatios, other.mainRatios) &&
          const ListEquality().equals(nestedRatios1, other.nestedRatios1) &&
          const ListEquality().equals(nestedRatios2, other.nestedRatios2);

  @override
  int get hashCode =>
      const ListEquality().hash(mainRatios) ^
      const ListEquality().hash(nestedRatios1) ^
      const ListEquality().hash(nestedRatios2);
}
