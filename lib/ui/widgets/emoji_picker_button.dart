import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class EmojiPickerButton extends StatelessWidget {
  const EmojiPickerButton({
    super.key,
    required this.value,
    required this.onPicked,
    this.size = 56,
    this.placeholder = Icons.tag_faces_rounded,
    this.label,
  });

  final String? value;
  final ValueChanged<String?> onPicked;
  final double size;
  final IconData placeholder;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final hasEmoji = value != null && value!.isNotEmpty;
    return Tooltip(
      message: label ?? 'Pick an icon',
      child: GestureDetector(
        onTap: () => _open(context),
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: hasEmoji ? palette.accentSoft : palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasEmoji ? Colors.transparent : palette.border,
            ),
          ),
          alignment: Alignment.center,
          child: hasEmoji
              ? Text(
                  value!,
                  style: TextStyle(fontSize: size * 0.5, height: 1.1),
                )
              : Icon(placeholder, color: palette.textSecondary, size: 22),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final palette = OrgPaletteScope.of(context);
    final result = await showModalBottomSheet<_EmojiPickResult>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SizedBox(
              height: 360,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 14, 6),
                    child: Row(
                      children: [
                        Text(
                          label ?? 'Pick an icon',
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(color: palette.text),
                        ),
                        const Spacer(),
                        if (value != null && value!.isNotEmpty)
                          TextButton(
                            onPressed: () => Navigator.of(
                              sheetContext,
                            ).pop(const _EmojiPickResult(clear: true)),
                            child: Text(
                              'Clear',
                              style: TextStyle(color: palette.danger),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ep.EmojiPicker(
                      onEmojiSelected: (_, emoji) {
                        Navigator.of(
                          sheetContext,
                        ).pop(_EmojiPickResult(emoji: emoji.emoji));
                      },
                      config: ep.Config(
                        height: 340,
                        emojiViewConfig: ep.EmojiViewConfig(
                          backgroundColor: palette.surface,
                          columns: 8,
                          emojiSizeMax: 26,
                          verticalSpacing: 2,
                          horizontalSpacing: 0,
                        ),
                        categoryViewConfig: ep.CategoryViewConfig(
                          backgroundColor: palette.surface,
                          indicatorColor: palette.accent,
                          iconColor: palette.textTertiary,
                          iconColorSelected: palette.accent,
                          tabIndicatorAnimDuration: OrgDurations.toggle,
                        ),
                        bottomActionBarConfig: ep.BottomActionBarConfig(
                          backgroundColor: palette.bg,
                          buttonColor: palette.bg,
                          buttonIconColor: palette.textSecondary,
                        ),
                        searchViewConfig: ep.SearchViewConfig(
                          backgroundColor: palette.bg,
                          buttonIconColor: palette.textSecondary,
                          hintText: 'Search',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == null) return;
    if (result.clear) {
      onPicked(null);
    } else if (result.emoji != null) {
      onPicked(result.emoji);
    }
  }
}

class _EmojiPickResult {
  const _EmojiPickResult({this.emoji, this.clear = false});

  final String? emoji;
  final bool clear;
}
