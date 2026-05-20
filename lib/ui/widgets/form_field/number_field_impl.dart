import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class NumberFieldImpl extends StatefulWidget {
  const NumberFieldImpl({
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
  State<NumberFieldImpl> createState() => _NumberFieldImplState();
}

class _NumberFieldImplState extends State<NumberFieldImpl> {
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
    final field = widget.field;
    final digits = field.digits;
    final hintParts = <String>[
      if (field.hint != null && field.hint!.isNotEmpty) field.hint!,
      if (digits != null) '$digits digits',
      if (field.min != null && field.max != null)
        'Range ${field.min}–${field.max}',
      if (field.min != null && field.max == null) 'Min ${field.min}',
      if (field.max != null && field.min == null) 'Max ${field.max}',
    ];

    final formatters = <TextInputFormatter>[
      if (digits != null) ...[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(digits),
      ] else
        FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*\.?[0-9]*')),
    ];

    return FormFieldHost(
      label: field.label,
      required: field.isRequired,
      focused: _focused,
      accent: widget.accent,
      error: widget.error,
      hint: hintParts.isEmpty ? null : hintParts.join(' · '),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: digits != null
            ? TextInputType.number
            : const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
        textInputAction: TextInputAction.next,
        cursorColor: widget.accent ?? palette.accent,
        inputFormatters: formatters,
        onChanged: (_) => widget.onChanged(),
        style: TextStyle(
          color: palette.text,
          fontWeight: FontWeight.w600,
          fontFamily: 'JetBrainsMono',
          fontSize: 15,
          letterSpacing: -0.01,
        ),
        decoration: InputDecoration(
          hintText: field.hint,
          hintStyle: TextStyle(
            color: palette.textTertiary,
            fontWeight: FontWeight.w500,
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
