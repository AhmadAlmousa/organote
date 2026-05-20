import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class IpFieldImpl extends StatefulWidget {
  const IpFieldImpl({
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
  State<IpFieldImpl> createState() => _IpFieldImplState();
}

class _IpFieldImplState extends State<IpFieldImpl> {
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
      hint: widget.field.hint ?? 'IPv4 — four numbers 0–255',
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        cursorColor: widget.accent ?? palette.accent,
        inputFormatters: <TextInputFormatter>[_IpInputFormatter()],
        onChanged: (_) => widget.onChanged(),
        style: TextStyle(
          color: palette.text,
          fontWeight: FontWeight.w600,
          fontFamily: 'JetBrainsMono',
          fontSize: 15,
          letterSpacing: -0.01,
        ),
        decoration: InputDecoration(
          hintText: '192.168.1.1',
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

class _IpInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    if (raw.isEmpty) return newValue;
    final filtered = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = filtered.split('.');
    if (parts.length > 4) return oldValue;
    for (final part in parts) {
      if (part.length > 3) return oldValue;
      if (part.isNotEmpty) {
        final number = int.tryParse(part);
        if (number == null || number > 255) return oldValue;
      }
    }
    if (filtered == raw) {
      return newValue;
    }
    return TextEditingValue(
      text: filtered,
      selection: TextSelection.collapsed(offset: filtered.length),
    );
  }
}
