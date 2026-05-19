import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrgTypography {
  const OrgTypography._();

  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.3,
    double letterSpacing = -0.005,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.35,
    double letterSpacing = -0.01,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme buildTextTheme(Color baseColor) {
    final base = GoogleFonts.plusJakartaSansTextTheme();
    return TextTheme(
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.03,
        color: baseColor,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.028,
        color: baseColor,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.025,
        color: baseColor,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.025,
        color: baseColor,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
        color: baseColor,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.015,
        color: baseColor,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.012,
        color: baseColor,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.01,
        color: baseColor,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.005,
        color: baseColor,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: baseColor,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: 0.04,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: baseColor,
        letterSpacing: 0.06,
      ),
    );
  }
}
