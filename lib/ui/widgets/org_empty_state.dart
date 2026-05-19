import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';

class OrgEmptyState extends StatelessWidget {
  const OrgEmptyState({
    super.key,
    required this.emoji,
    required this.message,
    this.subtitle,
    this.action,
  });

  final String emoji;
  final String message;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(
          color: palette.borderStrong,
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(20),
        color: palette.surface.withAlpha(140),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: TextStyle(
              fontSize: 36,
              fontFamily: 'monospace',
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.textTertiary),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}
