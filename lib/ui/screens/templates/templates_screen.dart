import 'package:flutter/material.dart';

import '../../theme/color_tokens.dart';
import '../../widgets/org_empty_state.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: const Center(
        child: OrgEmptyState(
          emoji: '◌',
          message: 'Templates screen lands in Phase 7',
          subtitle: 'Schemas, stats, and field builders are coming soon.',
        ),
      ),
    );
  }
}
