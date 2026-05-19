import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class OrgFab extends StatefulWidget {
  const OrgFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.tooltip,
    this.size = 60,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final double size;

  @override
  State<OrgFab> createState() => _OrgFabState();
}

class _OrgFabState extends State<OrgFab> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final scale = _down
        ? 0.94
        : _hover
        ? 1.06
        : 1.0;
    final rotation = _hover ? 0.14 : 0.0; // ≈8°

    return Semantics(
      label: widget.tooltip,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: scale,
            duration: OrgDurations.press,
            curve: OrgCurves.spring,
            child: AnimatedRotation(
              turns: rotation / 6.283,
              duration: OrgDurations.press,
              curve: OrgCurves.spring,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accentSoft,
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                      spreadRadius: -4,
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: palette.onAccent,
                  size: 24,
                  weight: 700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
