import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class TextFieldImpl extends StatefulWidget {
  const TextFieldImpl({
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
  State<TextFieldImpl> createState() => _TextFieldImplState();
}

class _TextFieldImplState extends State<TextFieldImpl> {
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
    final multiline = widget.field.multiline;
    final maxLength = widget.field.maxLength;
    final hintParts = <String>[
      if (widget.field.hint != null && widget.field.hint!.isNotEmpty)
        widget.field.hint!,
      if (widget.field.minLength != null || maxLength != null)
        _lengthHint(widget.field.minLength, maxLength),
    ].where((s) => s.isNotEmpty).toList();

    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      focused: _focused,
      accent: widget.accent,
      error: widget.error,
      hint: hintParts.isEmpty ? null : hintParts.join(' · '),
      trailing: maxLength != null
          ? _CharCountIndicator(
              controller: widget.controller,
              maxLength: maxLength,
              palette: palette,
              accent: widget.accent ?? palette.accent,
            )
          : null,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        maxLines: multiline ? null : 1,
        minLines: multiline ? 3 : 1,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        textInputAction: multiline
            ? TextInputAction.newline
            : TextInputAction.next,
        cursorColor: widget.accent ?? palette.accent,
        inputFormatters: maxLength != null
            ? <TextInputFormatter>[LengthLimitingTextInputFormatter(maxLength)]
            : null,
        onChanged: (_) => widget.onChanged(),
        style: TextStyle(
          color: palette.text,
          fontWeight: FontWeight.w500,
          fontSize: 15,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: widget.field.hint,
          hintStyle: TextStyle(
            color: palette.textTertiary,
            fontWeight: FontWeight.w500,
          ),
          isCollapsed: true,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  String _lengthHint(int? min, int? max) {
    if (min != null && max != null) return '$min–$max chars';
    if (max != null) return 'Up to $max chars';
    if (min != null) return 'At least $min chars';
    return '';
  }
}

class _CharCountIndicator extends StatelessWidget {
  const _CharCountIndicator({
    required this.controller,
    required this.maxLength,
    required this.palette,
    required this.accent,
  });

  final TextEditingController controller;
  final int maxLength;
  final OrgPalette palette;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final used = value.text.characters.length;
        final near = used >= maxLength * 0.85;
        final over = used > maxLength;
        return Text(
          '$used / $maxLength',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: over
                ? palette.danger
                : near
                ? accent
                : palette.textTertiary,
          ),
        );
      },
    );
  }
}
