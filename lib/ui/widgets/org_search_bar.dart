import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class OrgSearchBar extends StatefulWidget {
  const OrgSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.placeholder = 'Search notes, fields, values…',
    this.onFilter,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final VoidCallback? onFilter;

  @override
  State<OrgSearchBar> createState() => _OrgSearchBarState();
}

class _OrgSearchBarState extends State<OrgSearchBar> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return AnimatedContainer(
      duration: OrgDurations.toggle,
      curve: OrgCurves.spring,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused ? palette.accent : palette.border,
          width: _focused ? 1.4 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: palette.accentSoft,
                  blurRadius: 18,
                  spreadRadius: -6,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: palette.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              cursorColor: palette.accent,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          if (widget.onFilter != null)
            Material(
              color: palette.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: widget.onFilter,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(
                    Icons.tune_rounded,
                    color: palette.onAccent,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
