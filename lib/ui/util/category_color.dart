import 'dart:ui';

import '../../domain/models/models.dart';
import 'oklch.dart';

final RegExp _hexPattern = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

Color? parseHexColor(String? value) {
  if (value == null) return null;
  final match = _hexPattern.firstMatch(value);
  if (match == null) return null;
  final hex = match.group(1)!;
  final padded = hex.length == 6 ? 'FF$hex' : hex;
  return Color(int.parse(padded, radix: 16));
}

double hueOfCategory(Category category, {double fallbackHue = 175}) {
  final color = parseHexColor(category.colorHex);
  if (color == null) return fallbackHue;
  return _hueFromColor(color);
}

double _hueFromColor(Color color) {
  final r = ((color.toARGB32() >> 16) & 0xff) / 255.0;
  final g = ((color.toARGB32() >> 8) & 0xff) / 255.0;
  final b = (color.toARGB32() & 0xff) / 255.0;

  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
  final delta = max - min;
  if (delta == 0) return 0;

  double hue;
  if (max == r) {
    hue = ((g - b) / delta) % 6;
  } else if (max == g) {
    hue = (b - r) / delta + 2;
  } else {
    hue = (r - g) / delta + 4;
  }
  hue *= 60;
  if (hue < 0) hue += 360;
  return hue;
}

Color accentForHue(double hue) => oklchToColor(0.82, 0.16, hue);
Color softForHue(double hue, [double alpha = 0.16]) =>
    oklchToColor(0.82, 0.16, hue, alpha: alpha);
Color deepForHue(double hue) => oklchToColor(0.32, 0.07, hue);
