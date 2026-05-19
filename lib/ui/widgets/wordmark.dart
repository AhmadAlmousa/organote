import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';

class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    this.size = 22,
    this.color,
    this.accent,
    this.showName = true,
  });

  final double size;
  final Color? color;
  final Color? accent;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final mark = color ?? palette.text;
    final dot = accent ?? palette.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size * 1.15,
          height: size * 1.15,
          child: CustomPaint(
            painter: _WordmarkPainter(mark: mark, accent: dot),
          ),
        ),
        if (showName) ...[
          SizedBox(width: size * 0.34),
          Text(
            'Organote',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w800,
              fontSize: size,
              letterSpacing: -0.025 * size,
              height: 1,
              color: mark,
            ),
          ),
        ],
      ],
    );
  }
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter({required this.mark, required this.accent});

  final Color mark;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 24;
    final centerO = Offset(12 * unit, 12 * unit);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = mark
      ..strokeWidth = 2.4 * unit;
    canvas.drawCircle(centerO, 10 * unit, ring);

    final dot = Paint()..color = accent;
    canvas.drawCircle(centerO, 4.2 * unit, dot);
    canvas.drawCircle(Offset(17.5 * unit, 6.5 * unit), 2.2 * unit, dot);
  }

  @override
  bool shouldRepaint(covariant _WordmarkPainter oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.accent != accent;
}
