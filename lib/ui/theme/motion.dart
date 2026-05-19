import 'package:flutter/animation.dart';

class OrgCurves {
  const OrgCurves._();

  static const Cubic spring = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Cubic sheet = Cubic(0.34, 1.16, 0.64, 1.0);
  static const Cubic snap = Cubic(0.2, 0.7, 0.4, 1.0);
  static const Cubic easeOutQuint = Cubic(0.22, 1, 0.36, 1);
}

class OrgDurations {
  const OrgDurations._();

  static const Duration tap = Duration(milliseconds: 150);
  static const Duration press = Duration(milliseconds: 180);
  static const Duration hover = Duration(milliseconds: 180);
  static const Duration toggle = Duration(milliseconds: 200);
  static const Duration ripple = Duration(milliseconds: 650);
  static const Duration toast = Duration(milliseconds: 1400);
  static const Duration overlay = Duration(milliseconds: 320);
  static const Duration sheet = Duration(milliseconds: 300);
  static const Duration page = Duration(milliseconds: 280);
}
