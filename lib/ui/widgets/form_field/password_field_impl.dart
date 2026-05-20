import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class PasswordFieldImpl extends StatefulWidget {
  const PasswordFieldImpl({
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
  State<PasswordFieldImpl> createState() => _PasswordFieldImplState();
}

class _PasswordFieldImplState extends State<PasswordFieldImpl> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;
  bool _reveal = false;

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
    final accent = widget.accent ?? palette.accent;
    final maxLength = widget.field.maxLength;
    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      focused: _focused,
      accent: widget.accent,
      error: widget.error,
      hint: widget.field.hint,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              obscureText: !_reveal,
              obscuringCharacter: '•',
              keyboardType: TextInputType.visiblePassword,
              autocorrect: false,
              enableSuggestions: false,
              cursorColor: accent,
              inputFormatters: maxLength != null
                  ? <TextInputFormatter>[
                      LengthLimitingTextInputFormatter(maxLength),
                    ]
                  : null,
              onChanged: (_) => widget.onChanged(),
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w600,
                fontFamily: 'JetBrainsMono',
                fontSize: 15,
                letterSpacing: -0.01,
              ),
              decoration: InputDecoration(
                hintText: widget.field.hint,
                hintStyle: TextStyle(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w500,
                  fontFamily: null,
                ),
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _reveal = !_reveal),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
              child: Text(
                _reveal ? 'HIDE' : 'SHOW',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: _reveal ? accent : palette.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
