import 'package:flutter/material.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import 'form_field_host.dart';

class PlaceholderFieldImpl extends StatelessWidget {
  const PlaceholderFieldImpl({
    super.key,
    required this.field,
    required this.controller,
    required this.onChanged,
    this.accent,
    this.error,
  });

  final TemplateField field;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final Color? accent;
  final String? error;

  String get _phaseLabel {
    switch (field.type) {
      case TemplateFieldType.date:
      case TemplateFieldType.image:
      case TemplateFieldType.customLabel:
        return 'Phase 6';
      case TemplateFieldType.regex:
        return 'Phase 5';
      default:
        return 'soon';
    }
  }

  IconData get _icon {
    switch (field.type) {
      case TemplateFieldType.date:
        return Icons.calendar_today_rounded;
      case TemplateFieldType.image:
        return Icons.image_outlined;
      case TemplateFieldType.customLabel:
        return Icons.bookmarks_outlined;
      case TemplateFieldType.regex:
        return Icons.code_rounded;
      default:
        return Icons.build_circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accentColor = accent ?? palette.accent;
    return FormFieldHost(
      label: field.label,
      required: field.isRequired,
      accent: accent,
      error: error,
      hint: 'Editor lands in $_phaseLabel — value preserved as plain text',
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              cursorColor: accentColor,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: field.hint ?? 'Raw value (typed editor coming soon)',
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
          ),
        ],
      ),
    );
  }
}
