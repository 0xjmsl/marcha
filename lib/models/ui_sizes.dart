import 'app_settings.dart';

/// UI size configuration with category-based scaling
/// Each category uses TextSizePreset (S/M/L/XL = 1.0/1.2/1.4/1.6x)
class UiSizes {
  final TextSizePreset paneHeaders;
  final TextSizePreset tasksPane;
  final TextSizePreset historyPane;
  final TextSizePreset logView;
  final TextSizePreset terminal;
  final TextSizePreset toolbar;

  const UiSizes({
    this.paneHeaders = TextSizePreset.medium,
    this.tasksPane = TextSizePreset.medium,
    this.historyPane = TextSizePreset.medium,
    this.logView = TextSizePreset.medium,
    this.terminal = TextSizePreset.medium,
    this.toolbar = TextSizePreset.medium,
  });

  /// Default UI sizes (all medium)
  factory UiSizes.defaults() => const UiSizes();

  // === PANE HEADERS ===
  double get paneHeaderHeight => 28 * paneHeaders.scale;
  double get paneHeaderIconSize => 14 * paneHeaders.scale;
  double get paneHeaderDragIconSize => 12 * paneHeaders.scale;
  double get paneHeaderTitleFontSize => 10 * paneHeaders.scale;
  double get paneHeaderInfoFontSize => 10 * paneHeaders.scale;
  double get paneHeaderButtonIconSize => 14 * paneHeaders.scale;
  double get paneHeaderButtonPadding => 4 * paneHeaders.scale;

  // === TASKS PANE ===
  double get groupRowHeight => 28 * tasksPane.scale;
  double get groupExpandIconSize => 16 * tasksPane.scale;
  double get groupEmojiSize => 12 * tasksPane.scale;
  double get groupTitleFontSize => 10 * tasksPane.scale;
  double get groupCountFontSize => 10 * tasksPane.scale;
  double get groupActionIconSize => 14 * tasksPane.scale;

  double get taskRowHeight => 36 * tasksPane.scale;
  double get taskBulletSize => 6 * tasksPane.scale;
  double get taskEmojiSize => 14 * tasksPane.scale;
  double get taskNameFontSize => 13 * tasksPane.scale;
  double get taskCommandFontSize => 10 * tasksPane.scale;
  double get taskActionIconSize => 16 * tasksPane.scale;

  // === HISTORY PANE ===
  double get historyRowHeight => 40 * historyPane.scale;
  double get historyStatusDotSize => 8 * historyPane.scale;
  double get historyEmojiSize => 12 * historyPane.scale;
  double get historyNameFontSize => 13 * historyPane.scale;
  double get historyTimeFontSize => 10 * historyPane.scale;
  double get historyActionIconSize => 14 * historyPane.scale;

  // === LOG VIEW ===
  double get logHeaderHeight => 28 * logView.scale;
  double get logHeaderIconSize => 14 * logView.scale;
  double get logHeaderDragIconSize => 12 * logView.scale;
  double get logHeaderTitleFontSize => 12 * logView.scale;
  double get logContentFontSize => 14 * logView.scale;
  double get logContentPadding => 8 * logView.scale;

  // === TERMINAL ===
  double get terminalHeaderHeight => 28 * terminal.scale;
  double get terminalDragIconSize => 12 * terminal.scale;
  double get terminalStatusIndicatorSize => 10 * terminal.scale;
  double get terminalTitleFontSize => 12 * terminal.scale;
  double get terminalPidFontSize => 10 * terminal.scale;
  double get terminalActionIconSize => 14 * terminal.scale;
  double get terminalQuickActionEmojiSize => 12 * terminal.scale;

  // === TOOLBAR ===
  double get toolbarHeight => 36 * toolbar.scale;
  double get toolbarIconSize => 16 * toolbar.scale;
  double get toolbarTitleFontSize => 14 * toolbar.scale;

  /// Create from JSON
  factory UiSizes.fromJson(Map<String, dynamic> json) {
    return UiSizes(
      paneHeaders: TextSizePreset.values.firstWhere(
        (e) => e.name == json['paneHeaders'],
        orElse: () => TextSizePreset.medium,
      ),
      tasksPane: TextSizePreset.values.firstWhere(
        (e) => e.name == json['tasksPane'],
        orElse: () => TextSizePreset.medium,
      ),
      historyPane: TextSizePreset.values.firstWhere(
        (e) => e.name == json['historyPane'],
        orElse: () => TextSizePreset.medium,
      ),
      logView: TextSizePreset.values.firstWhere(
        (e) => e.name == json['logView'],
        orElse: () => TextSizePreset.medium,
      ),
      terminal: TextSizePreset.values.firstWhere(
        (e) => e.name == json['terminal'],
        orElse: () => TextSizePreset.medium,
      ),
      toolbar: TextSizePreset.values.firstWhere(
        (e) => e.name == json['toolbar'],
        orElse: () => TextSizePreset.medium,
      ),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'paneHeaders': paneHeaders.name,
        'tasksPane': tasksPane.name,
        'historyPane': historyPane.name,
        'logView': logView.name,
        'terminal': terminal.name,
        'toolbar': toolbar.name,
      };

  /// Create copy with optional overrides
  UiSizes copyWith({
    TextSizePreset? paneHeaders,
    TextSizePreset? tasksPane,
    TextSizePreset? historyPane,
    TextSizePreset? logView,
    TextSizePreset? terminal,
    TextSizePreset? toolbar,
  }) {
    return UiSizes(
      paneHeaders: paneHeaders ?? this.paneHeaders,
      tasksPane: tasksPane ?? this.tasksPane,
      historyPane: historyPane ?? this.historyPane,
      logView: logView ?? this.logView,
      terminal: terminal ?? this.terminal,
      toolbar: toolbar ?? this.toolbar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UiSizes &&
          runtimeType == other.runtimeType &&
          paneHeaders == other.paneHeaders &&
          tasksPane == other.tasksPane &&
          historyPane == other.historyPane &&
          logView == other.logView &&
          terminal == other.terminal &&
          toolbar == other.toolbar;

  @override
  int get hashCode =>
      paneHeaders.hashCode ^
      tasksPane.hashCode ^
      historyPane.hashCode ^
      logView.hashCode ^
      terminal.hashCode ^
      toolbar.hashCode;
}
