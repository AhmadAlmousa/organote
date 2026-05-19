import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/adaptive_shell.dart';
import 'app/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/templates/templates_screen.dart';
import 'theme/app_theme.dart';
import 'theme/color_tokens.dart';
import 'theme/theme_controller.dart';

class OrganoteApp extends ConsumerWidget {
  const OrganoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final themeState = ref.watch(themeProvider);
    final palette = themeState.palette(platformBrightness);
    final theme = OrgTheme.build(palette);
    return MaterialApp(
      title: 'Organote',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: _RootGate(palette: palette),
      builder: (context, child) {
        return OrgPaletteScope(
          palette: palette,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _RootGate extends StatefulWidget {
  const _RootGate({required this.palette});

  final OrgPalette palette;

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return SplashScreen(onReady: () => setState(() => _ready = true));
    }
    return const AdaptiveShell(
      home: HomeScreen(),
      templates: TemplatesScreen(),
      settings: SettingsScreen(),
    );
  }
}
