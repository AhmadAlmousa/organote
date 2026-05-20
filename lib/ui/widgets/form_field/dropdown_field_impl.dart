import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import '../../theme/motion.dart';
import 'form_field_host.dart';

class DropdownFieldImpl extends StatefulWidget {
  const DropdownFieldImpl({
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
  State<DropdownFieldImpl> createState() => _DropdownFieldImplState();
}

class _DropdownFieldImplState extends State<DropdownFieldImpl> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accent = widget.accent ?? palette.accent;
    final options = widget.field.options;
    final value = widget.controller.text;
    final selected = options.contains(value) ? value : null;
    final hintParts = <String>[
      if (widget.field.hint != null && widget.field.hint!.isNotEmpty)
        widget.field.hint!,
      if (options.isEmpty) 'No options defined yet',
    ];

    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      focused: _focused,
      accent: widget.accent,
      error: widget.error,
      hint: hintParts.isEmpty ? null : hintParts.join(' · '),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 4, 6, 4),
      child: options.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Add options in the template builder',
                style: TextStyle(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : Theme(
              data: Theme.of(context).copyWith(
                hoverColor: palette.surfaceHigh,
                focusColor: palette.surfaceHigh,
                splashColor: palette.accentSoft,
              ),
              child: DropdownButtonHideUnderline(
                child: Focus(
                  onFocusChange: (focused) =>
                      setState(() => _focused = focused),
                  child: DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    isDense: true,
                    icon: AnimatedRotation(
                      turns: _focused ? 0.5 : 0,
                      duration: OrgDurations.toggle,
                      curve: OrgCurves.spring,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: accent,
                      ),
                    ),
                    iconSize: 22,
                    dropdownColor: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    hint: Text(
                      'Select…',
                      style: TextStyle(
                        color: palette.textTertiary,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final option in options)
                        DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ),
                    ],
                    onChanged: (next) {
                      if (next == null) return;
                      widget.controller.text = next;
                      widget.onChanged();
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
