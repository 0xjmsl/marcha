import 'package:flutter/material.dart';
import '../core/core.dart';
import '../core/settings_extension.dart';
import '../models/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/terminal_theme.dart';

/// Settings screen with compact, organized layout
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TerminalTheme? _editingTheme;
  bool _colorsExpanded = false;

  TerminalTheme get _currentTheme => _editingTheme ?? core.settings.terminalTheme;

  @override
  Widget build(BuildContext context) {
    final settings = core.settings.current;
    final styles = AppTheme.of(context);
    final colors = AppColorsExtension.of(context);

    return Container(
      color: colors.background,
      child: Column(
        children: [
          // Compact header
          _buildHeader(styles, colors),

          // Scrollable content with max width
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    // UI Scale section
                    _buildSection(
                      colors: colors,
                      title: 'Interface',
                      icon: Icons.text_fields,
                      children: [
                        _buildInlineOption(
                          colors: colors,
                          label: 'UI Scale',
                          child: _buildSegmentedButtons(
                            colors: colors,
                            values: TextSizePreset.values,
                            selected: settings.textSizePreset,
                            labelBuilder: (p) => p.shortName,
                            onSelected: (p) async {
                              await core.settings.setTextSizePreset(p);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInlineOption(
                          colors: colors,
                          label: 'Resources',
                          child: _buildSegmentedButtons(
                            colors: colors,
                            values: TextSizePreset.values,
                            selected: settings.resourcesTextSizePreset,
                            labelBuilder: (p) => p.shortName,
                            onSelected: (p) async {
                              await core.settings.setResourcesTextSizePreset(p);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInlineOption(
                          colors: colors,
                          label: 'Theme',
                          child: _buildSegmentedButtons(
                            colors: colors,
                            values: [true, false],
                            selected: settings.isDarkMode,
                            labelBuilder: (v) => v ? 'Dark' : 'Light',
                            onSelected: (v) async {
                              await core.settings.setDarkMode(v);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Terminal section
                    _buildSection(
                      colors: colors,
                      title: 'Terminal',
                      icon: Icons.terminal,
                      children: [
                        _buildInlineOption(
                          colors: colors,
                          label: 'Font Size',
                          child: _buildSegmentedButtons(
                            colors: colors,
                            values: TextSizePreset.values,
                            selected: settings.terminalFontSizePreset,
                            labelBuilder: (p) => p.shortName,
                            onSelected: (p) async {
                              await core.settings.setTerminalFontSizePreset(p);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildThemeGrid(settings, styles, colors),
                        const SizedBox(height: 12),
                        _buildTerminalPreview(styles),
                        const SizedBox(height: 12),
                        _buildColorCustomization(styles, colors),
                        if (_editingTheme != null) ...[const SizedBox(height: 12), _buildSaveBar(styles, colors)],
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Limits section
                    _buildSection(
                      colors: colors,
                      title: 'Limits',
                      icon: Icons.security,
                      children: [
                        _buildSliderOption(
                          colors: colors,
                          label: 'Max Concurrent Tasks',
                          sublabel: 'Running: ${core.history.running.length}',
                          value: settings.maxConcurrentTasks,
                          min: 1,
                          max: SettingsExtension.absoluteMaxTasks,
                          onChanged: (v) async {
                            await core.settings.setMaxConcurrentTasks(v);
                            setState(() {});
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppTextStyles styles, AppColorScheme colors) {
    return Container(
      height: 36 * styles.scale,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: colors.textMuted, size: 16),
          const SizedBox(width: 8),
          Text('Settings', style: AppTheme.bodyNormal.copyWith(color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSection({required AppColorScheme colors, required String title, required IconData icon, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 14, color: colors.textMuted),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textMuted, letterSpacing: 0.8),
              ),
            ],
          ),
        ),
        // Section content
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }

  Widget _buildInlineOption({required AppColorScheme colors, required String label, required Widget child}) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        ),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildSegmentedButtons<T>({required AppColorScheme colors, required List<T> values, required T selected, required String Function(T) labelBuilder, required void Function(T) onSelected}) {
    return Row(
      children: values.map((value) {
        final isSelected = value == selected;
        final isFirst = value == values.first;
        final isLast = value == values.last;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(value),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : colors.surfaceLight,
                borderRadius: BorderRadius.horizontal(left: isFirst ? const Radius.circular(4) : Radius.zero, right: isLast ? const Radius.circular(4) : Radius.zero),
                border: Border.all(color: isSelected ? AppColors.accent : colors.border),
              ),
              child: Center(
                child: Text(
                  labelBuilder(value),
                  style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? Colors.white : colors.textSecondary),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSliderOption({
    required AppColorScheme colors,
    required String label,
    required String sublabel,
    required int value,
    required int min,
    required int max,
    required void Function(int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: colors.textSecondary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: colors.surfaceLight, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '$value',
                style: TextStyle(fontSize: 12, fontFamily: 'Consolas', fontWeight: FontWeight.bold, color: colors.textBright),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: colors.surfaceLight,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accent.withAlpha(30),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: value.toDouble(), min: min.toDouble(), max: max.toDouble(), divisions: max - min, onChanged: (v) => onChanged(v.round())),
        ),
        Text(sublabel, style: TextStyle(fontSize: 11, color: colors.textMuted)),
      ],
    );
  }

  Widget _buildThemeGrid(AppSettings settings, AppTextStyles styles, AppColorScheme colors) {
    final builtInThemes = TerminalTheme.builtInThemes;
    final customThemes = settings.customTerminalThemes;
    final currentThemeId = settings.terminalThemeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color Theme', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
        const SizedBox(height: 10),
        // Compact theme chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [...builtInThemes.map((t) => _buildThemeChip(t, currentThemeId, canDelete: false)), ...customThemes.map((t) => _buildThemeChip(t, currentThemeId, canDelete: true))],
        ),
      ],
    );
  }

  Widget _buildThemeChip(TerminalTheme theme, String currentThemeId, {required bool canDelete}) {
    final isSelected = theme.id == currentThemeId && _editingTheme == null;

    return GestureDetector(
      onTap: () async {
        _editingTheme = null;
        await core.settings.setTerminalTheme(theme.id);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppColors.accent : theme.borderColor, width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color dots
            _colorDot(theme.runningColor, 6),
            const SizedBox(width: 3),
            _colorDot(theme.warningColor, 6),
            const SizedBox(width: 3),
            _colorDot(theme.errorColor, 6),
            const SizedBox(width: 8),
            Text(
              theme.name,
              style: TextStyle(fontSize: 11, color: theme.foreground, fontFamily: 'Consolas'),
            ),
            if (canDelete) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _deleteCustomTheme(theme.id, theme.name),
                child: Icon(Icons.close, size: 12, color: theme.foreground.withAlpha(150)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTerminalPreview(AppTextStyles styles) {
    final theme = _currentTheme;
    final fontScale = core.settings.terminalFontScale;
    final fontSize = 11.0 * fontScale;
    // Title bar (22) + padding (16) + 4 lines of text with 1.3 line height
    final previewHeight = 22.0 + 16.0 + (4 * fontSize * 1.3);

    return Container(
      height: previewHeight + 4,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Column(
          children: [
            // Mini title bar
            Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              color: theme.titleBarBackground,
              child: Row(
                children: [
                  _colorDot(theme.closeButtonColor, 8),
                  const SizedBox(width: 5),
                  _colorDot(theme.minimizeButtonColor, 8),
                  const SizedBox(width: 5),
                  _colorDot(theme.runningColor, 8),
                  const SizedBox(width: 8),
                  Text(
                    'Preview',
                    style: TextStyle(fontSize: 10, color: theme.foreground.withAlpha(150), fontFamily: 'Consolas'),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _previewLine('npm run dev', theme.foreground, fontSize),
                    _previewLine('Server started on :3000', theme.successColor, fontSize),
                    _previewLine('Warning: deprecated API', theme.warningColor, fontSize),
                    _previewLine('Error: module not found', theme.errorColor, fontSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewLine(String text, Color color, double fontSize) {
    return Text(
      text,
      style: TextStyle(fontFamily: 'Consolas', fontSize: fontSize, color: color, height: 1.3),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildColorCustomization(AppTextStyles styles, AppColorScheme colors) {
    final theme = _currentTheme;

    return Column(
      children: [
        // Expandable header
        GestureDetector(
          onTap: () => setState(() => _colorsExpanded = !_colorsExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(_colorsExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: colors.textMuted),
                const SizedBox(width: 6),
                Text('Customize Colors', style: TextStyle(fontSize: 12, color: colors.textMuted)),
              ],
            ),
          ),
        ),
        if (_colorsExpanded) ...[
          const SizedBox(height: 8),
          // Compact color grid
          _buildColorRow('Background', colors, [
            _colorItem('Main', theme.background, colors, (c) => _updateColor(background: c)),
            _colorItem('Title', theme.titleBarBackground, colors, (c) => _updateColor(titleBarBackground: c)),
            _colorItem('Input', theme.inputAreaBackground, colors, (c) => _updateColor(inputAreaBackground: c)),
            _colorItem('Border', theme.borderColor, colors, (c) => _updateColor(borderColor: c)),
          ]),
          const SizedBox(height: 12),
          _buildColorRow('Text', colors, [
            _colorItem('Main', theme.foreground, colors, (c) => _updateColor(foreground: c)),
            _colorItem('Time', theme.timestampColor, colors, (c) => _updateColor(timestampColor: c)),
            _colorItem('Prompt', theme.promptColor, colors, (c) => _updateColor(promptColor: c)),
            _colorItem('Exit', theme.exitCodeColor, colors, (c) => _updateColor(exitCodeColor: c)),
          ]),
          const SizedBox(height: 12),
          _buildColorRow('Status', colors, [
            _colorItem('Success', theme.successColor, colors, (c) => _updateColor(successColor: c)),
            _colorItem('Warning', theme.warningColor, colors, (c) => _updateColor(warningColor: c)),
            _colorItem('Error', theme.errorColor, colors, (c) => _updateColor(errorColor: c)),
            _colorItem('Running', theme.runningColor, colors, (c) => _updateColor(runningColor: c)),
          ]),
        ],
      ],
    );
  }

  Widget _buildColorRow(String label, AppColorScheme colors, List<Widget> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(label, style: TextStyle(fontSize: 11, color: colors.textMuted)),
          ),
        ),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: items),
        ),
      ],
    );
  }

  Widget _colorItem(String label, Color color, AppColorScheme colors, ValueChanged<Color> onChanged) {
    return GestureDetector(
      onTap: () => _showColorPicker(label, color, colors, onChanged),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.border),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 9, color: colors.textMuted)),
        ],
      ),
    );
  }

  void _showColorPicker(String label, Color currentColor, AppColorScheme colors, ValueChanged<Color> onChanged) {
    final controller = TextEditingController(text: currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        contentPadding: const EdgeInsets.all(20),
        title: Text(label, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
            ),
            const SizedBox(height: 16),
            // Hex input
            SizedBox(
              width: 120,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '#',
                  prefixStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                style: TextStyle(color: colors.textPrimary, fontFamily: 'Consolas', fontSize: 13),
                onChanged: (value) {
                  if (value.length == 6) {
                    final parsed = int.tryParse('FF$value', radix: 16);
                    if (parsed != null) {
                      onChanged(Color(parsed));
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            // Quick colors
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _quickColor(const Color(0xFFFF5555), colors, onChanged),
                _quickColor(const Color(0xFFFFB86C), colors, onChanged),
                _quickColor(const Color(0xFFF1FA8C), colors, onChanged),
                _quickColor(const Color(0xFF50FA7B), colors, onChanged),
                _quickColor(const Color(0xFF8BE9FD), colors, onChanged),
                _quickColor(const Color(0xFFBD93F9), colors, onChanged),
                _quickColor(const Color(0xFFFF79C6), colors, onChanged),
                _quickColor(const Color(0xFFF8F8F2), colors, onChanged),
                _quickColor(const Color(0xFF6272A4), colors, onChanged),
                _quickColor(const Color(0xFF282A36), colors, onChanged),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Widget _quickColor(Color color, AppColorScheme colors, ValueChanged<Color> onChanged) {
    return GestureDetector(
      onTap: () {
        onChanged(color);
        Navigator.pop(context);
      },
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.border),
        ),
      ),
    );
  }

  void _updateColor({
    Color? background,
    Color? inputAreaBackground,
    Color? titleBarBackground,
    Color? borderColor,
    Color? foreground,
    Color? timestampColor,
    Color? errorColor,
    Color? warningColor,
    Color? successColor,
    Color? promptColor,
    Color? exitCodeColor,
    Color? closeButtonColor,
    Color? minimizeButtonColor,
    Color? scrollButtonColor,
    Color? runningColor,
    Color? stoppedColor,
  }) {
    setState(() {
      _editingTheme = _currentTheme.copyWith(
        background: background,
        inputAreaBackground: inputAreaBackground,
        titleBarBackground: titleBarBackground,
        borderColor: borderColor,
        foreground: foreground,
        timestampColor: timestampColor,
        errorColor: errorColor,
        warningColor: warningColor,
        successColor: successColor,
        promptColor: promptColor,
        exitCodeColor: exitCodeColor,
        closeButtonColor: closeButtonColor,
        minimizeButtonColor: minimizeButtonColor,
        scrollButtonColor: scrollButtonColor,
        runningColor: runningColor,
        stoppedColor: stoppedColor,
      );
    });
  }

  Widget _buildSaveBar(AppTextStyles styles, AppColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.save_outlined, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Unsaved changes', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => setState(() => _editingTheme = null),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
            child: Text('Discard', style: TextStyle(fontSize: 12, color: colors.textMuted)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _showSaveDialog,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero),
            child: const Text('Save', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showSaveDialog() {
    final colors = AppColorsExtension.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Save Theme', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Theme name',
            hintStyle: TextStyle(color: colors.textMuted),
          ),
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
              final newTheme = _editingTheme!.copyWith(id: id, name: name, isBuiltIn: false);

              await core.settings.saveCustomTerminalTheme(newTheme);
              _editingTheme = null;

              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteCustomTheme(String themeId, String themeName) {
    final colors = AppColorsExtension.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Delete Theme', style: TextStyle(fontSize: 14, color: colors.textPrimary)),
        content: Text('Delete "$themeName"?', style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await core.settings.deleteCustomTerminalTheme(themeId);
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
