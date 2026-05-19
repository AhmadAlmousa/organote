import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/density.dart';
import '../theme/motion.dart';
import '../widgets/glass_panel.dart';

enum OrgTabId { home, templates, settings }

class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.home,
    required this.templates,
    required this.settings,
  });

  final Widget home;
  final Widget templates;
  final Widget settings;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  OrgTabId _tab = OrgTabId.home;

  Widget _screenFor(OrgTabId tab) => switch (tab) {
    OrgTabId.home => widget.home,
    OrgTabId.templates => widget.templates,
    OrgTabId.settings => widget.settings,
  };

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return OrgDensity(
      level: OrgDensityLevel.comfortable,
      child: Scaffold(
        backgroundColor: palette.bg,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: OrgDurations.page,
              switchInCurve: OrgCurves.sheet,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(key: ValueKey(_tab), child: _screenFor(_tab)),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 12,
              child: _BottomNav(
                current: _tab,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onSelect});

  final OrgTabId current;
  final ValueChanged<OrgTabId> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    const items = <_NavItem>[
      _NavItem(id: OrgTabId.home, icon: Icons.home_rounded, label: 'Home'),
      _NavItem(
        id: OrgTabId.templates,
        icon: Icons.dashboard_customize_rounded,
        label: 'Templates',
      ),
      _NavItem(
        id: OrgTabId.settings,
        icon: Icons.tune_rounded,
        label: 'Settings',
      ),
    ];
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _NavButton(
                item: item,
                active: current == item.id,
                onTap: () => onSelect(item.id),
                palette: palette,
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.id, required this.icon, required this.label});

  final OrgTabId id;
  final IconData icon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
    required this.palette,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.accent : palette.textTertiary;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      highlightShape: BoxShape.rectangle,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.spring,
        decoration: BoxDecoration(
          color: active ? palette.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(item.icon, size: 22, color: color),
                if (active)
                  Positioned(
                    top: -10,
                    child: Container(
                      width: 22,
                      height: 3,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.04,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
