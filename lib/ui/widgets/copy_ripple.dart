import 'package:flutter/material.dart';

import '../theme/motion.dart';

class CopyRippleOverlay extends StatefulWidget {
  const CopyRippleOverlay({
    super.key,
    required this.color,
    required this.borderRadius,
    required this.child,
    required this.controller,
  });

  final Color color;
  final BorderRadius borderRadius;
  final Widget child;
  final CopyRippleController controller;

  @override
  State<CopyRippleOverlay> createState() => _CopyRippleOverlayState();
}

class _CopyRippleOverlayState extends State<CopyRippleOverlay>
    with TickerProviderStateMixin {
  final List<_RippleSpec> _ripples = <_RippleSpec>[];
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_trigger);
  }

  @override
  void didUpdateWidget(covariant CopyRippleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._detach();
      widget.controller._attach(_trigger);
    }
  }

  @override
  void dispose() {
    widget.controller._detach();
    for (final spec in _ripples) {
      spec.controller.dispose();
    }
    super.dispose();
  }

  void _trigger(Offset position) {
    final controller = AnimationController(
      vsync: this,
      duration: OrgDurations.ripple,
    );
    final id = _nextId++;
    final spec = _RippleSpec(
      id: id,
      position: position,
      controller: controller,
    );
    setState(() => _ripples.add(spec));
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _ripples.removeWhere((r) => r.id == id));
      controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        widget.child,
        if (_ripples.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: Stack(
                  children: [
                    for (final spec in _ripples)
                      AnimatedBuilder(
                        animation: spec.controller,
                        builder: (_, _) {
                          return CustomPaint(
                            painter: _RipplePainter(
                              position: spec.position,
                              progress: spec.controller.value,
                              color: widget.color,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class CopyRippleController {
  void Function(Offset position)? _handler;

  void _attach(void Function(Offset position) handler) {
    _handler = handler;
  }

  void _detach() {
    _handler = null;
  }

  void trigger(Offset position) {
    _handler?.call(position);
  }
}

class _RippleSpec {
  _RippleSpec({
    required this.id,
    required this.position,
    required this.controller,
  });

  final int id;
  final Offset position;
  final AnimationController controller;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.position,
    required this.progress,
    required this.color,
  });

  final Offset position;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final maxRadius = (size.longestSide * 1.4) + 60;
    final radius = 6 + maxRadius * eased;
    final alpha = ((1 - eased) * 0.55 * 255).round().clamp(0, 255);
    final paint = Paint()..color = color.withAlpha(alpha);
    canvas.drawCircle(position, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
