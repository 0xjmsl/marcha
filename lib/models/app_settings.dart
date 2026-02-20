import 'package:collection/collection.dart';
import '../theme/terminal_theme.dart';
import 'layout_preset.dart';
import 'layout_sizes.dart';
import 'slot_assignment.dart';
import 'ui_sizes.dart';

/// Text size presets for app-wide scaling
enum TextSizePreset {
  small,
  medium,
  large,
  extraLarge;

  String get displayName => switch (this) {
        TextSizePreset.small => 'Small',
        TextSizePreset.medium => 'Medium',
        TextSizePreset.large => 'Large',
        TextSizePreset.extraLarge => 'Extra Large',
      };

  String get shortName => switch (this) {
        TextSizePreset.small => 'S',
        TextSizePreset.medium => 'M',
        TextSizePreset.large => 'L',
        TextSizePreset.extraLarge => 'XL',
      };

  double get scale => switch (this) {
        TextSizePreset.small => 1.0,
        TextSizePreset.medium => 1.2,
        TextSizePreset.large => 1.4,
        TextSizePreset.extraLarge => 1.6,
      };
}

/// Application settings model with JSON serialization
class AppSettings {
  final TextSizePreset textSizePreset;
  final TextSizePreset terminalFontSizePreset;
  final TextSizePreset resourcesTextSizePreset;
  final bool isDarkMode;
  final int maxConcurrentTasks;
  final String terminalThemeId;
  final List<TerminalTheme> customTerminalThemes;

  // Layout persistence fields
  final LayoutPreset layoutPreset;
  final List<SlotAssignment> slotAssignments;
  final Map<String, LayoutSizes> paneSizes;

  // UI sizes configuration
  final UiSizes uiSizes;

  // API settings
  final bool apiEnabled;
  final int apiPort;
  final List<String> apiAllowedAddresses;
  final Map<String, bool> apiEndpointToggles;
  final int apiTimestampTolerance;

  const AppSettings({
    this.textSizePreset = TextSizePreset.medium,
    this.terminalFontSizePreset = TextSizePreset.medium,
    this.resourcesTextSizePreset = TextSizePreset.medium,
    this.isDarkMode = true,
    this.maxConcurrentTasks = 10,
    this.terminalThemeId = 'default_dark',
    this.customTerminalThemes = const [],
    this.layoutPreset = LayoutPreset.threeColumns,
    this.slotAssignments = const [],
    this.paneSizes = const {},
    this.uiSizes = const UiSizes(),
    this.apiEnabled = false,
    this.apiPort = 7832,
    this.apiAllowedAddresses = const [],
    this.apiEndpointToggles = const {},
    this.apiTimestampTolerance = 300,
  });

  /// Scale factor for app text and icons
  double get textScale => textSizePreset.scale;

  /// Scale factor for terminal font
  double get terminalFontScale => terminalFontSizePreset.scale;

  /// Scale factor for resources pane text
  double get resourcesTextScale => resourcesTextSizePreset.scale;

  /// Default settings
  factory AppSettings.defaults() => const AppSettings();

  /// Create from JSON map
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final customThemesList = (json['customTerminalThemes'] as List<dynamic>?)
            ?.map((e) => TerminalTheme.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final slotAssignmentsList =
        (json['slotAssignments'] as List<dynamic>?)
                ?.map(
                    (e) => SlotAssignment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

    final paneSizesMap = (json['paneSizes'] as Map<String, dynamic>?)?.map(
          (key, value) =>
              MapEntry(key, LayoutSizes.fromJson(value as Map<String, dynamic>)),
        ) ??
        {};

    final uiSizesData = json['uiSizes'] as Map<String, dynamic>?;
    final uiSizes = uiSizesData != null ? UiSizes.fromJson(uiSizesData) : const UiSizes();

    return AppSettings(
      textSizePreset: TextSizePreset.values.firstWhere(
        (e) => e.name == json['textSizePreset'],
        orElse: () => TextSizePreset.medium,
      ),
      terminalFontSizePreset: TextSizePreset.values.firstWhere(
        (e) => e.name == json['terminalFontSizePreset'],
        orElse: () => TextSizePreset.medium,
      ),
      resourcesTextSizePreset: TextSizePreset.values.firstWhere(
        (e) => e.name == json['resourcesTextSizePreset'],
        orElse: () => TextSizePreset.medium,
      ),
      isDarkMode: json['isDarkMode'] as bool? ?? true,
      maxConcurrentTasks: json['maxConcurrentTasks'] as int? ?? 10,
      terminalThemeId: json['terminalThemeId'] as String? ?? 'default_dark',
      customTerminalThemes: customThemesList,
      layoutPreset: LayoutPreset.fromName(
        json['layoutPreset'] as String? ?? 'threeColumns',
      ),
      slotAssignments: slotAssignmentsList,
      paneSizes: paneSizesMap,
      uiSizes: uiSizes,
      apiEnabled: json['apiEnabled'] as bool? ?? false,
      apiPort: json['apiPort'] as int? ?? 7832,
      apiAllowedAddresses: List<String>.from(json['apiAllowedAddresses'] ?? []),
      apiEndpointToggles: Map<String, bool>.from(json['apiEndpointToggles'] ?? {}),
      apiTimestampTolerance: json['apiTimestampTolerance'] as int? ?? 300,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
        'textSizePreset': textSizePreset.name,
        'terminalFontSizePreset': terminalFontSizePreset.name,
        'resourcesTextSizePreset': resourcesTextSizePreset.name,
        'isDarkMode': isDarkMode,
        'maxConcurrentTasks': maxConcurrentTasks,
        'terminalThemeId': terminalThemeId,
        'customTerminalThemes':
            customTerminalThemes.map((t) => t.toJson()).toList(),
        'layoutPreset': layoutPreset.name,
        'slotAssignments': slotAssignments.map((s) => s.toJson()).toList(),
        'paneSizes':
            paneSizes.map((key, value) => MapEntry(key, value.toJson())),
        'uiSizes': uiSizes.toJson(),
        'apiEnabled': apiEnabled,
        'apiPort': apiPort,
        'apiAllowedAddresses': apiAllowedAddresses,
        'apiEndpointToggles': apiEndpointToggles,
        'apiTimestampTolerance': apiTimestampTolerance,
      };

  /// Create copy with optional overrides
  AppSettings copyWith({
    TextSizePreset? textSizePreset,
    TextSizePreset? terminalFontSizePreset,
    TextSizePreset? resourcesTextSizePreset,
    bool? isDarkMode,
    int? maxConcurrentTasks,
    String? terminalThemeId,
    List<TerminalTheme>? customTerminalThemes,
    LayoutPreset? layoutPreset,
    List<SlotAssignment>? slotAssignments,
    Map<String, LayoutSizes>? paneSizes,
    UiSizes? uiSizes,
    bool? apiEnabled,
    int? apiPort,
    List<String>? apiAllowedAddresses,
    Map<String, bool>? apiEndpointToggles,
    int? apiTimestampTolerance,
  }) {
    return AppSettings(
      textSizePreset: textSizePreset ?? this.textSizePreset,
      terminalFontSizePreset:
          terminalFontSizePreset ?? this.terminalFontSizePreset,
      resourcesTextSizePreset:
          resourcesTextSizePreset ?? this.resourcesTextSizePreset,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
      terminalThemeId: terminalThemeId ?? this.terminalThemeId,
      customTerminalThemes: customTerminalThemes ?? this.customTerminalThemes,
      layoutPreset: layoutPreset ?? this.layoutPreset,
      slotAssignments: slotAssignments ?? this.slotAssignments,
      paneSizes: paneSizes ?? this.paneSizes,
      uiSizes: uiSizes ?? this.uiSizes,
      apiEnabled: apiEnabled ?? this.apiEnabled,
      apiPort: apiPort ?? this.apiPort,
      apiAllowedAddresses: apiAllowedAddresses ?? this.apiAllowedAddresses,
      apiEndpointToggles: apiEndpointToggles ?? this.apiEndpointToggles,
      apiTimestampTolerance: apiTimestampTolerance ?? this.apiTimestampTolerance,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          textSizePreset == other.textSizePreset &&
          terminalFontSizePreset == other.terminalFontSizePreset &&
          resourcesTextSizePreset == other.resourcesTextSizePreset &&
          isDarkMode == other.isDarkMode &&
          maxConcurrentTasks == other.maxConcurrentTasks &&
          terminalThemeId == other.terminalThemeId &&
          const ListEquality()
              .equals(customTerminalThemes, other.customTerminalThemes) &&
          layoutPreset == other.layoutPreset &&
          const ListEquality()
              .equals(slotAssignments, other.slotAssignments) &&
          const MapEquality().equals(paneSizes, other.paneSizes) &&
          uiSizes == other.uiSizes &&
          apiEnabled == other.apiEnabled &&
          apiPort == other.apiPort &&
          const ListEquality()
              .equals(apiAllowedAddresses, other.apiAllowedAddresses) &&
          const MapEquality()
              .equals(apiEndpointToggles, other.apiEndpointToggles) &&
          apiTimestampTolerance == other.apiTimestampTolerance;

  @override
  int get hashCode =>
      textSizePreset.hashCode ^
      terminalFontSizePreset.hashCode ^
      resourcesTextSizePreset.hashCode ^
      isDarkMode.hashCode ^
      maxConcurrentTasks.hashCode ^
      terminalThemeId.hashCode ^
      const ListEquality().hash(customTerminalThemes) ^
      layoutPreset.hashCode ^
      const ListEquality().hash(slotAssignments) ^
      const MapEquality().hash(paneSizes) ^
      uiSizes.hashCode ^
      apiEnabled.hashCode ^
      apiPort.hashCode ^
      const ListEquality().hash(apiAllowedAddresses) ^
      const MapEquality().hash(apiEndpointToggles) ^
      apiTimestampTolerance.hashCode;
}
