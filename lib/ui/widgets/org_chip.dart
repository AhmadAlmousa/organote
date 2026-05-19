import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class OrgChip extends StatefulWidget {
  const OrgChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.count,
    this.hueColor,
    this.softColor,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  final Color? hueColor;
  final Color? softColor;

  @override
  State<OrgChip> createState() => _OrgChipState();
}

class _OrgChipState extends State<OrgChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final hue = widget.hueColor ?? palette.accent;
    final soft = widget.softColor ?? palette.accentSoft;
    final activeText = palette.brightness == Brightness.dark
        ? hue
        : palette.onAccent;

    final bg = widget.active
        ? soft
        : (_hover ? palette.surfaceHigh : palette.surface);
    final fg = widget.active ? activeText : palette.textSecondary;
    final border = widget.active ? Colors.transparent : palette.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: soft,
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.005,
                  fontSize: 13.5,
                ),
              ),
              if (widget.count != null) ...[
                const SizedBox(width: 6),
                _CountBadge(count: widget.count!, active: widget.active),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.active});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: active
            ? palette.accent
            : palette.surfaceHigh.withAlpha(
                palette.brightness == Brightness.dark ? 64 : 96,
              ),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          height: 1,
          color: active ? palette.onAccent : palette.textSecondary,
        ),
      ),
    );
  }
}
