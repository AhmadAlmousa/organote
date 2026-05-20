import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class UrlFieldImpl extends StatefulWidget {
  const UrlFieldImpl({
    super.key,
    required this.field,
    required this.controller,
    required this.onChanged,
    this.error,
    this.accent,
  });

  final TemplateField field;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;
  final Color? accent;

  @override
  State<UrlFieldImpl> createState() => _UrlFieldImplState();
}

class _UrlFieldImplState extends State<UrlFieldImpl> {
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
    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      focused: _focused,
      accent: widget.accent,
      error: widget.error,
      hint: widget.field.hint ?? 'https://…',
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: widget.accent ?? palette.accent,
        onChanged: (_) => widget.onChanged(),
        style: TextStyle(
          color: palette.text,
          fontWeight: FontWeight.w500,
          fontFamily: 'JetBrainsMono',
          fontSize: 14.5,
          letterSpacing: -0.01,
        ),
        decoration: InputDecoration(
          hintText: 'https://example.com',
          hintStyle: TextStyle(
            color: palette.textTertiary,
            fontWeight: FontWeight.w500,
            fontFamily: 'JetBrainsMono',
          ),
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}
