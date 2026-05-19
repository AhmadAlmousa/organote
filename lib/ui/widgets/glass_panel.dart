import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 20,
    this.opacity = 0.78,
    this.borderColor,
    this.padding,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final border = borderColor ?? palette.border;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: palette.surface.withAlpha((opacity * 255).round()),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: palette.shadowStrong,
                blurRadius: 50,
                offset: const Offset(0, 22),
                spreadRadius: -10,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
