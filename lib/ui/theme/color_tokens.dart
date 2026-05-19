import 'package:flutter/material.dart';

import '../util/oklch.dart';

class OrgAccentPreset {
  const OrgAccentPreset({required this.name, required this.hue});

  final String name;
  final double hue;

  Color get color => oklchToColor(0.82, 0.16, hue);
}

class OrgAccents {
  const OrgAccents._();

  static const OrgAccentPreset mint = OrgAccentPreset(name: 'Mint', hue: 175);
  static const OrgAccentPreset violet = OrgAccentPreset(
    name: 'Violet',
    hue: 295,
  );
  static const OrgAccentPreset coral = OrgAccentPreset(name: 'Coral', hue: 25);
  static const OrgAccentPreset lemon = OrgAccentPreset(name: 'Lemon', hue: 95);
  static const OrgAccentPreset azure = OrgAccentPreset(name: 'Azure', hue: 240);

  static const List<OrgAccentPreset> presets = <OrgAccentPreset>[
    mint,
    violet,
    coral,
    lemon,
    azure,
  ];
}

@immutable
class OrgPalette {
  const OrgPalette({
    required this.bg,
    required this.bgSecondary,
    required this.surface,
    required this.surfaceHigh,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.onAccent,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.borderStrong,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadowSoft,
    required this.shadowStrong,
    required this.brightness,
    required this.accentHue,
    required this.oled,
  });

  final Color bg;
  final Color bgSecondary;
  final Color surface;
  final Color surfaceHigh;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final Color onAccent;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color border;
  final Color borderStrong;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadowSoft;
  final Color shadowStrong;
  final Brightness brightness;
  final double accentHue;
  final bool oled;

  bool get isDark => brightness == Brightness.dark;

  Color categoryColor(double hue) => oklchToColor(0.82, 0.16, hue);
  Color categorySoft(double hue, [double alpha = 0.16]) =>
      oklchToColor(0.82, 0.16, hue, alpha: alpha);
  Color categoryDeep(double hue) => oklchToColor(0.32, 0.07, hue);
}

class OrgColors {
  const OrgColors._();

  static OrgPalette palette({
    required Brightness brightness,
    required double accentHue,
    bool oled = false,
  }) {
    final accent = oklchToColor(0.82, 0.16, accentHue);
    final accentSoft = oklchToColor(0.82, 0.16, accentHue, alpha: 0.18);
    final accentDeep = oklchToColor(0.32, 0.07, accentHue);
    final onAccent = oklchToColor(0.18, 0.012, accentHue);

    if (brightness == Brightness.dark) {
      final bg = oled
          ? const Color(0xFF000000)
          : oklchToColor(0.18, 0.012, 175);
      final bgSecondary = oled
          ? const Color(0xFF050505)
          : oklchToColor(0.16, 0.010, 175);
      final surface = oled
          ? const Color(0xFF0B0B0B)
          : oklchToColor(0.23, 0.014, 175);
      final surfaceHigh = oled
          ? const Color(0xFF161616)
          : oklchToColor(0.27, 0.016, 175);
      return OrgPalette(
        bg: bg,
        bgSecondary: bgSecondary,
        surface: surface,
        surfaceHigh: surfaceHigh,
        accent: accent,
        accentSoft: accentSoft,
        accentDeep: accentDeep,
        onAccent: onAccent,
        text: oklchToColor(0.95, 0.005, 175),
        textSecondary: oklchToColor(0.72, 0.012, 175),
        textTertiary: oklchToColor(0.52, 0.010, 175),
        border: const Color(0x12FFFFFF),
        borderStrong: const Color(0x22FFFFFF),
        success: oklchToColor(0.82, 0.18, 145),
        warning: oklchToColor(0.82, 0.18, 75),
        danger: oklchToColor(0.78, 0.17, 25),
        shadowSoft: const Color(0x73000000),
        shadowStrong: const Color(0x99000000),
        brightness: brightness,
        accentHue: accentHue,
        oled: oled,
      );
    }

    return OrgPalette(
      bg: oklchToColor(0.985, 0.005, 175),
      bgSecondary: oklchToColor(0.96, 0.006, 175),
      surface: const Color(0xFFFFFFFF),
      surfaceHigh: oklchToColor(0.97, 0.006, 175),
      accent: accent,
      accentSoft: oklchToColor(0.82, 0.16, accentHue, alpha: 0.20),
      accentDeep: accentDeep,
      onAccent: onAccent,
      text: oklchToColor(0.18, 0.012, 175),
      textSecondary: oklchToColor(0.40, 0.014, 175),
      textTertiary: oklchToColor(0.55, 0.014, 175),
      border: const Color(0x12000000),
      borderStrong: const Color(0x24000000),
      success: oklchToColor(0.62, 0.18, 145),
      warning: oklchToColor(0.72, 0.18, 75),
      danger: oklchToColor(0.62, 0.17, 25),
      shadowSoft: const Color(0x1A000000),
      shadowStrong: const Color(0x2E000000),
      brightness: brightness,
      accentHue: accentHue,
      oled: false,
    );
  }

  static ColorScheme scheme(OrgPalette palette) {
    return ColorScheme(
      brightness: palette.brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentSoft,
      onPrimaryContainer: palette.accent,
      secondary: palette.accentDeep,
      onSecondary: palette.text,
      secondaryContainer: palette.accentSoft,
      onSecondaryContainer: palette.accent,
      tertiary: palette.accent,
      onTertiary: palette.onAccent,
      tertiaryContainer: palette.accentSoft,
      onTertiaryContainer: palette.accent,
      error: palette.danger,
      onError: palette.text,
      errorContainer: palette.danger.withAlpha(40),
      onErrorContainer: palette.danger,
      surface: palette.surface,
      onSurface: palette.text,
      onSurfaceVariant: palette.textSecondary,
      surfaceContainerLowest: palette.bgSecondary,
      surfaceContainerLow: palette.bg,
      surfaceContainer: palette.surface,
      surfaceContainerHigh: palette.surfaceHigh,
      surfaceContainerHighest: palette.surfaceHigh,
      surfaceTint: palette.accent,
      outline: palette.borderStrong,
      outlineVariant: palette.border,
      shadow: palette.shadowStrong,
      scrim: palette.brightness == Brightness.dark
          ? const Color(0x99000000)
          : const Color(0x66000000),
      inverseSurface: palette.brightness == Brightness.dark
          ? palette.text
          : palette.bg,
      onInverseSurface: palette.brightness == Brightness.dark
          ? palette.bg
          : palette.text,
      inversePrimary: palette.accentDeep,
    );
  }
}

class OrgPaletteScope extends InheritedWidget {
  const OrgPaletteScope({
    super.key,
    required this.palette,
    required super.child,
  });

  final OrgPalette palette;

  static OrgPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OrgPaletteScope>();
    assert(scope != null, 'OrgPaletteScope missing in widget tree');
    return scope!.palette;
  }

  @override
  bool updateShouldNotify(OrgPaletteScope oldWidget) =>
      oldWidget.palette != palette;
}
