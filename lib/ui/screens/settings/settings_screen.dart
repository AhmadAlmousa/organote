import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/color_tokens.dart';
import '../../theme/theme_controller.dart';
import '../../widgets/org_empty_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = OrgPaletteScope.of(context);
    final theme = ref.watch(themeProvider);
    return Scaffold(
      backgroundColor: palette.bg,
      body: Center(
        child: OrgEmptyState(
          emoji: '⚙',
          message: 'Settings screen lands in Phase 8',
          subtitle:
              'Accent hue ${theme.accentHue.toStringAsFixed(0)}° · Theme ${theme.themePreference.name}',
        ),
      ),
    );
  }
}
