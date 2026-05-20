import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class CustomLabelFieldImpl extends StatefulWidget {
  const CustomLabelFieldImpl({
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
  State<CustomLabelFieldImpl> createState() => _CustomLabelFieldImplState();
}

class _CustomLabelFieldImplState extends State<CustomLabelFieldImpl> {
  late final TextEditingController _labelController;
  late final TextEditingController _valueController;
  final FocusNode _labelFocus = FocusNode();
  final FocusNode _valueFocus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    final parsed = _split(widget.controller.text);
    _labelController = TextEditingController(text: parsed.label);
    _valueController = TextEditingController(text: parsed.value);
    _labelFocus.addListener(_syncFocus);
    _valueFocus.addListener(_syncFocus);
  }

  @override
  void dispose() {
    _labelFocus
      ..removeListener(_syncFocus)
      ..dispose();
    _valueFocus
      ..removeListener(_syncFocus)
      ..dispose();
    _labelController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _syncFocus() {
    setState(() => _focused = _labelFocus.hasFocus || _valueFocus.hasFocus);
  }

  void _compose() {
    final label = _labelController.text.trim();
    final value = _valueController.text.trim();
    widget.controller.text = label.isEmpty && value.isEmpty
        ? ''
        : '$label: $value';
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      focused: _focused,
      accent: widget.accent,
      error: widget.error,
      hint: widget.field.hint ?? 'Stored as Label: Value',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final first = _MiniTextField(
            key: Key('custom-label-${widget.field.id}-label'),
            label: 'Label',
            controller: _labelController,
            focusNode: _labelFocus,
            accent: widget.accent,
            onChanged: _compose,
          );
          final second = _MiniTextField(
            key: Key('custom-label-${widget.field.id}-value'),
            label: 'Value',
            controller: _valueController,
            focusNode: _valueFocus,
            accent: widget.accent,
            onChanged: _compose,
          );
          if (compact) {
            return Column(
              children: [first, const SizedBox(height: 10), second],
            );
          }
          return Row(
            children: [
              Expanded(child: first),
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
                child: Text(
                  ':',
                  style: TextStyle(
                    color: OrgPaletteScope.of(context).textTertiary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              Expanded(child: second),
            ],
          );
        },
      ),
    );
  }

  _CustomLabelParts _split(String raw) {
    final index = raw.indexOf(':');
    if (index < 0) return _CustomLabelParts(label: '', value: raw.trim());
    return _CustomLabelParts(
      label: raw.substring(0, index).trim(),
      value: raw.substring(index + 1).trim(),
    );
  }
}

class _MiniTextField extends StatelessWidget {
  const _MiniTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color? accent;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      cursorColor: accent ?? palette.accent,
      onChanged: (_) => onChanged(),
      style: TextStyle(
        color: palette.text,
        fontWeight: FontWeight.w600,
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        hintText: label,
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
    );
  }
}

class _CustomLabelParts {
  const _CustomLabelParts({required this.label, required this.value});

  final String label;
  final String value;
}
