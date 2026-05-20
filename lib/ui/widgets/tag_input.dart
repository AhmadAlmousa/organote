import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.tags,
    required this.onChanged,
    required this.suggestions,
    this.accent,
  });

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;
  final Color? accent;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return;
    if (widget.tags.contains(normalized)) {
      _controller.clear();
      return;
    }
    widget.onChanged(<String>[...widget.tags, normalized]);
    _controller.clear();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  String _normalize(String raw) => raw
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '')
      .toLowerCase();

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accent = widget.accent ?? palette.accent;
    final query = _controller.text.trim().toLowerCase();
    final matches = query.isEmpty
        ? const <String>[]
        : widget.suggestions
              .where(
                (t) =>
                    t.toLowerCase().contains(query) && !widget.tags.contains(t),
              )
              .take(5)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? accent : palette.border,
              width: _focused ? 1.4 : 1.0,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: accent.withAlpha(40),
                      blurRadius: 16,
                      spreadRadius: -8,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final tag in widget.tags)
                _Chip(
                  label: tag,
                  accent: accent,
                  palette: palette,
                  onRemove: () => _removeTag(tag),
                ),
              IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 80),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    cursorColor: accent,
                    onSubmitted: _addTag,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.done,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.tags.isEmpty ? 'Add tag…' : 'tag…',
                      hintStyle: TextStyle(
                        color: palette.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ),
              if (_controller.text.trim().isNotEmpty)
                GestureDetector(
                  onTap: () => _addTag(_controller.text),
                  child: Container(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: palette.onAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        letterSpacing: 0.04,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in matches)
                GestureDetector(
                  onTap: () => _addTag(tag),
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: palette.bgSecondary,
                      border: Border.all(color: palette.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+ #$tag',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.accent,
    required this.palette,
    required this.onRemove,
  });

  final String label;
  final Color accent;
  final OrgPalette palette;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$label',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: accent),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }
}
