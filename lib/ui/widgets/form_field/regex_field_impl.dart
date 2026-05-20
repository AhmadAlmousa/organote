import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class RegexFieldImpl extends StatefulWidget {
  const RegexFieldImpl({
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
  State<RegexFieldImpl> createState() => _RegexFieldImplState();
}

class _RegexFieldImplState extends State<RegexFieldImpl> {
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
    final accent = widget.accent ?? palette.accent;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final status = _statusFor(value.text);
        return FormFieldHost(
          label: widget.field.label,
          required: widget.field.isRequired,
          focused: _focused,
          accent: widget.accent,
          error: widget.error,
          hint: _hint(status),
          trailing: _RegexStatusBadge(status: status, accent: accent),
          child: TextField(
            key: Key('regex-field-${widget.field.id}'),
            controller: widget.controller,
            focusNode: _focus,
            cursorColor: accent,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              setState(() {});
              widget.onChanged();
            },
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w600,
              fontFamily: 'JetBrainsMono',
              fontSize: 14.5,
              letterSpacing: -0.01,
            ),
            decoration: InputDecoration(
              hintText: widget.field.hint ?? 'Value to test',
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
        );
      },
    );
  }

  _RegexStatus _statusFor(String raw) {
    final pattern = widget.field.regex?.trim();
    if (pattern == null || pattern.isEmpty) return _RegexStatus.noPattern;
    try {
      final regex = RegExp(pattern);
      if (raw.trim().isEmpty) return _RegexStatus.empty;
      return regex.hasMatch(raw) ? _RegexStatus.match : _RegexStatus.noMatch;
    } on FormatException {
      return _RegexStatus.badPattern;
    }
  }

  String _hint(_RegexStatus status) {
    final hint = widget.field.hint;
    final pattern = widget.field.regex?.trim();
    final parts = <String>[
      if (hint != null && hint.isNotEmpty) hint,
      if (pattern != null && pattern.isNotEmpty) 'Pattern $pattern',
      switch (status) {
        _RegexStatus.badPattern => 'Template pattern is invalid',
        _RegexStatus.noPattern => 'No pattern configured',
        _ => '',
      },
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? 'Live regex validation' : parts.join(' · ');
  }
}

enum _RegexStatus { empty, match, noMatch, noPattern, badPattern }

class _RegexStatusBadge extends StatelessWidget {
  const _RegexStatusBadge({required this.status, required this.accent});

  final _RegexStatus status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final (label, color, icon) = switch (status) {
      _RegexStatus.match => ('MATCH', palette.success, Icons.check_rounded),
      _RegexStatus.noMatch => (
        'NO MATCH',
        palette.warning,
        Icons.close_rounded,
      ),
      _RegexStatus.noPattern => (
        'RAW',
        palette.textTertiary,
        Icons.code_rounded,
      ),
      _RegexStatus.badPattern => (
        'BAD REGEX',
        palette.danger,
        Icons.error_outline_rounded,
      ),
      _RegexStatus.empty => ('TEST', accent, Icons.rule_rounded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.06,
          ),
        ),
      ],
    );
  }
}
