import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class OrgIconButton extends StatefulWidget {
  const OrgIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 38,
    this.iconSize = 20,
    this.background,
    this.foreground,
    this.borderColor,
    this.radius = 12,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double radius;
  final bool filled;

  @override
  State<OrgIconButton> createState() => _OrgIconButtonState();
}

class _OrgIconButtonState extends State<OrgIconButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final bg =
        widget.background ?? (widget.filled ? palette.accent : palette.surface);
    final fg =
        widget.foreground ?? (widget.filled ? palette.onAccent : palette.text);
    final border =
        widget.borderColor ??
        (widget.filled ? Colors.transparent : palette.border);

    final scale = _down
        ? 0.92
        : _hover
        ? 1.03
        : 1.0;
    final hoverBg = _hover && !widget.filled ? palette.surfaceHigh : bg;

    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        cursor: widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: scale,
            duration: OrgDurations.tap,
            curve: OrgCurves.spring,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: hoverBg,
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(color: border),
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: widget.iconSize, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
