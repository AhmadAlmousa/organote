import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/density.dart';
import 'mobile_shell.dart';

class WebShell extends StatefulWidget {
  const WebShell({
    super.key,
    required this.home,
    required this.templates,
    required this.settings,
  });

  final Widget home;
  final Widget templates;
  final Widget settings;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  OrgTabId _tab = OrgTabId.home;

  Widget _screenFor(OrgTabId tab) => switch (tab) {
    OrgTabId.home => widget.home,
    OrgTabId.templates => widget.templates,
    OrgTabId.settings => widget.settings,
  };

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SideRail(current: _tab, onSelect: (t) => setState(() => _tab = t)),
            Container(width: 1, color: palette.border),
            Expanded(
              child: OrgDensity(
                level: OrgDensityLevel.compact,
                child: _screenFor(_tab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.current, required this.onSelect});

  final OrgTabId current;
  final ValueChanged<OrgTabId> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    const items = <_RailItem>[
      _RailItem(id: OrgTabId.home, icon: Icons.home_rounded, label: 'Home'),
      _RailItem(
        id: OrgTabId.templates,
        icon: Icons.dashboard_customize_rounded,
        label: 'Templates',
      ),
      _RailItem(
        id: OrgTabId.settings,
        icon: Icons.tune_rounded,
        label: 'Settings',
      ),
    ];
    return Container(
      width: 64,
      color: palette.bgSecondary,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          for (final item in items)
            _RailButton(
              item: item,
              active: current == item.id,
              onTap: () => onSelect(item.id),
            ),
        ],
      ),
    );
  }
}

class _RailItem {
  const _RailItem({required this.id, required this.icon, required this.label});

  final OrgTabId id;
  final IconData icon;
  final String label;
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _RailItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final color = active ? palette.accent : palette.textTertiary;
    return Tooltip(
      message: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: active ? palette.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(item.icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}
