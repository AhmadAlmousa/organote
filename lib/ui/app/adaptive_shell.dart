import 'package:flutter/material.dart';

import 'mobile_shell.dart';
import 'web_shell.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.home,
    required this.templates,
    required this.settings,
  });

  final Widget home;
  final Widget templates;
  final Widget settings;

  static const double webBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= webBreakpoint) {
      return WebShell(home: home, templates: templates, settings: settings);
    }
    return MobileShell(home: home, templates: templates, settings: settings);
  }
}
