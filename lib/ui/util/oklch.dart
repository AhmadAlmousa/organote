import 'dart:math' as math;
import 'dart:ui';

Color oklchToColor(double l, double c, double h, {double alpha = 1.0}) {
  final hRad = h * math.pi / 180.0;
  final a = c * math.cos(hRad);
  final b = c * math.sin(hRad);

  final lMs = l + 0.3963377774 * a + 0.2158037573 * b;
  final mMs = l - 0.1055613458 * a - 0.0638541728 * b;
  final sMs = l - 0.0894841775 * a - 1.2914855480 * b;

  final lLms = lMs * lMs * lMs;
  final mLms = mMs * mMs * mMs;
  final sLms = sMs * sMs * sMs;

  final r = 4.0767416621 * lLms - 3.3077115913 * mLms + 0.2309699292 * sLms;
  final g = -1.2684380046 * lLms + 2.6097574011 * mLms - 0.3413193965 * sLms;
  final bl = -0.0041960863 * lLms - 0.7034186147 * mLms + 1.7076147010 * sLms;

  int channel(double v) => (_linearToSrgb(v) * 255.0).round().clamp(0, 255);

  return Color.fromARGB(
    (alpha.clamp(0.0, 1.0) * 255.0).round(),
    channel(r),
    channel(g),
    channel(bl),
  );
}

double _linearToSrgb(double v) {
  final clamped = v.clamp(0.0, 1.0);
  if (clamped <= 0.0031308) return clamped * 12.92;
  return 1.055 * math.pow(clamped, 1 / 2.4) - 0.055;
}

Color withAlphaFraction(Color color, double alpha) {
  return color.withAlpha((alpha.clamp(0.0, 1.0) * 255).round());
}
