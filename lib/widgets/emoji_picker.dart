import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Emoji categories with their emojis
const Map<String, List<String>> _emojiCategories = {
  'Common': [
    '🚀', '⚡', '🔧', '📦', '🎯', '✅', '📋', '💻',
    '🖥️', '⚙️', '🔨', '🛠️', '📁', '📂', '🗂️', '💾',
  ],
  'Development': [
    '💻', '🖥️', '⌨️', '🖱️', '💿', '📀', '🔌', '🔋',
    '📱', '📲', '🌐', '🔗', '🔒', '🔓', '🔑', '🗝️',
  ],
  'Status': [
    '✅', '❌', '⚠️', '❓', '❗', '💡', '🔔', '🔕',
    '▶️', '⏸️', '⏹️', '⏯️', '⏭️', '⏮️', '🔄', '🔃',
  ],
  'Objects': [
    '📊', '📈', '📉', '📋', '📌', '📍', '📎', '🔍',
    '📝', '✏️', '🖊️', '🖋️', '📕', '📗', '📘', '📙',
  ],
  'Nature': [
    '🌟', '⭐', '🌙', '☀️', '⛅', '🌈', '🔥', '💧',
    '🌊', '🌴', '🌲', '🌳', '🌺', '🌸', '🌻', '🍀',
  ],
  'Animals': [
    '🐱', '🐶', '🐰', '🦊', '🐻', '🐼', '🐨', '🦁',
    '🐯', '🐮', '🐷', '🐸', '🐵', '🦄', '🐝', '🦋',
  ],
  'Food': [
    '☕', '🍵', '🥤', '🍺', '🍕', '🍔', '🌮', '🍜',
    '🍰', '🎂', '🍩', '🍪', '🍎', '🍊', '🍋', '🍇',
  ],
  'Symbols': [
    '❤️', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎',
    '💯', '💢', '💥', '💫', '💬', '💭', '🏷️', '🎵',
  ],
};

/// Shows an emoji picker dialog and returns the selected emoji
Future<String?> showEmojiPicker(BuildContext context, {String? currentEmoji}) {
  return showDialog<String>(
    context: context,
    builder: (context) => EmojiPickerDialog(currentEmoji: currentEmoji),
  );
}

class EmojiPickerDialog extends StatefulWidget {
  final String? currentEmoji;

  const EmojiPickerDialog({super.key, this.currentEmoji});

  @override
  State<EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<EmojiPickerDialog> {
  String? _selectedEmoji;

  @override
  void initState() {
    super.initState();
    _selectedEmoji = widget.currentEmoji;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsExtension.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Select Emoji',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: colors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            // Emoji grid
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _emojiCategories.length,
                itemBuilder: (context, index) {
                  final category = _emojiCategories.keys.elementAt(index);
                  final emojis = _emojiCategories[category]!;
                  return _buildCategory(category, emojis, colors);
                },
              ),
            ),
            Divider(height: 1, color: colors.border),
            // Actions
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _selectedEmoji != null
                        ? () => Navigator.pop(context, _selectedEmoji)
                        : null,
                    child: const Text('Select'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String name, List<String> emojis, AppColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: emojis.map((emoji) => _buildEmojiButton(emoji)).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmojiButton(String emoji) {
    final isSelected = _selectedEmoji == emoji;
    return InkWell(
      onTap: () => setState(() => _selectedEmoji = emoji),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentDim : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.accent, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
