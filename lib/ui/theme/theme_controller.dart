import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../state/app_providers.dart';
import 'color_tokens.dart';

enum OrgLoadingAnimation { ripple, stagger, orbit, pulse }

@immutable
class ThemeState {
  const ThemeState({
    required this.themePreference,
    required this.accentHue,
    required this.oled,
    required this.localeCode,
    required this.loadingAnimation,
  });

  factory ThemeState.initial() => ThemeState(
    themePreference: ThemePreference.system,
    accentHue: OrgAccents.mint.hue,
    oled: false,
    localeCode: 'en',
    loadingAnimation: OrgLoadingAnimation.ripple,
  );

  final ThemePreference themePreference;
  final double accentHue;
  final bool oled;
  final String localeCode;
  final OrgLoadingAnimation loadingAnimation;

  ThemeState copyWith({
    ThemePreference? themePreference,
    double? accentHue,
    bool? oled,
    String? localeCode,
    OrgLoadingAnimation? loadingAnimation,
  }) {
    return ThemeState(
      themePreference: themePreference ?? this.themePreference,
      accentHue: accentHue ?? this.accentHue,
      oled: oled ?? this.oled,
      localeCode: localeCode ?? this.localeCode,
      loadingAnimation: loadingAnimation ?? this.loadingAnimation,
    );
  }

  Brightness resolveBrightness(Brightness platformBrightness) {
    switch (themePreference) {
      case ThemePreference.light:
        return Brightness.light;
      case ThemePreference.dark:
      case ThemePreference.oled:
        return Brightness.dark;
      case ThemePreference.system:
        return platformBrightness;
    }
  }

  bool resolveOled(Brightness brightness) {
    if (brightness == Brightness.light) return false;
    if (themePreference == ThemePreference.oled) return true;
    return oled;
  }

  OrgPalette palette(Brightness platformBrightness) {
    final brightness = resolveBrightness(platformBrightness);
    final isOled = resolveOled(brightness);
    return OrgColors.palette(
      brightness: brightness,
      accentHue: accentHue,
      oled: isOled,
    );
  }
}

class _ThemeKeys {
  static const String accentHue = 'organote.ui.accentHue';
  static const String oled = 'organote.ui.oled';
  static const String themePreference = 'organote.ui.themePreference';
  static const String localeCode = 'organote.ui.locale';
  static const String loadingAnimation = 'organote.ui.loadingAnimation';
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final themeIndex = prefs.getInt(_ThemeKeys.themePreference);
    final themePreference = themeIndex == null
        ? ThemePreference.system
        : ThemePreference.values[themeIndex.clamp(
            0,
            ThemePreference.values.length - 1,
          )];
    final loadingIndex =
        prefs.getInt(_ThemeKeys.loadingAnimation) ??
        OrgLoadingAnimation.ripple.index;
    return ThemeState(
      themePreference: themePreference,
      accentHue: prefs.getDouble(_ThemeKeys.accentHue) ?? OrgAccents.mint.hue,
      oled: prefs.getBool(_ThemeKeys.oled) ?? false,
      localeCode: prefs.getString(_ThemeKeys.localeCode) ?? 'en',
      loadingAnimation: OrgLoadingAnimation
          .values[loadingIndex.clamp(0, OrgLoadingAnimation.values.length - 1)],
    );
  }

  Future<void> setThemePreference(ThemePreference value) async {
    if (state.themePreference == value) return;
    state = state.copyWith(themePreference: value);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_ThemeKeys.themePreference, value.index);
  }

  Future<void> setAccentHue(double value) async {
    if (state.accentHue == value) return;
    state = state.copyWith(accentHue: value);
    await ref
        .read(sharedPreferencesProvider)
        .setDouble(_ThemeKeys.accentHue, value);
  }

  Future<void> setOled(bool value) async {
    if (state.oled == value) return;
    state = state.copyWith(oled: value);
    await ref.read(sharedPreferencesProvider).setBool(_ThemeKeys.oled, value);
  }

  Future<void> setLocale(String value) async {
    if (state.localeCode == value) return;
    state = state.copyWith(localeCode: value);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_ThemeKeys.localeCode, value);
  }

  Future<void> setLoadingAnimation(OrgLoadingAnimation value) async {
    if (state.loadingAnimation == value) return;
    state = state.copyWith(loadingAnimation: value);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_ThemeKeys.loadingAnimation, value.index);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
