import 'package:flutter/material.dart';

import '../../theme/color_tokens.dart';
import '../../theme/motion.dart';

class FormFieldHost extends StatelessWidget {
  const FormFieldHost({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
    this.error,
    this.trailing,
    this.focused = false,
    this.accent,
    this.contentPadding,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? hint;
  final String? error;
  final Widget? trailing;
  final bool focused;
  final Color? accent;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accentColor = accent ?? palette.accent;
    final hasError = error != null && error!.isNotEmpty;
    final borderColor = hasError
        ? palette.danger
        : focused
        ? accentColor
        : palette.border;
    final shadow = focused && !hasError
        ? <BoxShadow>[
            BoxShadow(
              color: accentColor.withAlpha(48),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 6),
            ),
          ]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(2, 0, 2, 6),
          child: Row(
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: focused ? accentColor : palette.textTertiary,
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                Text(
                  '•',
                  style: TextStyle(
                    color: palette.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 0.8,
                  ),
                ),
              ],
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
        ),
        AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: focused || hasError ? 1.4 : 1.0,
            ),
            boxShadow: shadow,
          ),
          padding:
              contentPadding ??
              const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
          child: child,
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 0),
            child: Text(
              error!,
              style: TextStyle(
                color: palette.danger,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          )
        else if (hint != null && hint!.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 4, 0),
            child: Text(
              hint!,
              style: TextStyle(
                color: palette.textTertiary,
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }
}
