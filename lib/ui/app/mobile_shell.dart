import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/color_tokens.dart';
import '../theme/density.dart';
import '../theme/motion.dart';
import '../widgets/glass_panel.dart';
import '../widgets/org_toast.dart';

enum OrgTabId { home, templates, settings }

/// Exposes the visible height of the floating bottom nav so screens can
/// reserve safe bottom padding for FABs, lists, and other anchored content.
class OrgMobileChrome extends InheritedWidget {
  const OrgMobileChrome({
    super.key,
    required this.bottomInset,
    required super.child,
  });

  final double bottomInset;

  static double bottomInsetOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<OrgMobileChrome>();
    return scope?.bottomInset ?? 0;
  }

  @override
  bool updateShouldNotify(OrgMobileChrome oldWidget) =>
      oldWidget.bottomInset != bottomInset;
}

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
  static const double _navBarVisibleHeight = 64;
  static const double _navBarBottomPad = 12;
  static const Duration _exitToastWindow = Duration(seconds: 2);

  final PageController _pageController = PageController();
  OrgTabId _tab = OrgTabId.home;
  DateTime? _lastBackPress;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(OrgTabId tab) {
    if (_tab == tab) return;
    final index = OrgTabId.values.indexOf(tab);
    setState(() => _tab = tab);
    _pageController.animateToPage(
      index,
      duration: OrgDurations.page,
      curve: OrgCurves.easeOutQuint,
    );
  }

  bool _handleBack() {
    if (_tab != OrgTabId.home) {
      _selectTab(OrgTabId.home);
      return false;
    }
    final now = DateTime.now();
    final last = _lastBackPress;
    if (last != null && now.difference(last) <= _exitToastWindow) {
      return true;
    }
    _lastBackPress = now;
    showOrgToast(
      context,
      message: 'Press back again to exit',
      icon: Icons.logout_rounded,
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final navInset = _navBarVisibleHeight + _navBarBottomPad + safeBottom;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = _handleBack();
        if (!shouldPop || !mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: OrgDensity(
        level: OrgDensityLevel.comfortable,
        child: OrgMobileChrome(
          bottomInset: navInset,
          child: Scaffold(
            backgroundColor: palette.bg,
            body: Stack(
              children: [
                PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    final next = OrgTabId.values[index];
                    if (next != _tab) {
                      setState(() => _tab = next);
                    }
                  },
                  children: [widget.home, widget.templates, widget.settings],
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: safeBottom + _navBarBottomPad,
                  child: _BottomNav(current: _tab, onSelect: _selectTab),
                ),
              ],
            ),
          ),
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
