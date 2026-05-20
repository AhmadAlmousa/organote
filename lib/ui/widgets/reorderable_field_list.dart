import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

/// Drag-to-reorder list with a springy lifted-card proxy and animated item
/// entry/exit.  Caller is responsible for providing [Key]s on each child.
class ReorderableFieldList extends StatelessWidget {
  const ReorderableFieldList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      onReorder: onReorder,
      proxyDecorator: (child, _, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (ctx, ch) {
            final t = CurvedAnimation(
              parent: animation,
              curve: OrgCurves.spring,
            ).value;
            return Material(
              elevation: 0,
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.0 + t * 0.025,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadowStrong.withAlpha(
                          (t * 110).clamp(0, 255).toInt(),
                        ),
                        blurRadius: 20 * t,
                        spreadRadius: -2,
                        offset: Offset(0, 8 * t),
                      ),
                    ],
                  ),
                  child: ch,
                ),
              ),
            );
          },
          child: child,
        );
      },
    );
  }
}

/// Wraps a child with a spring slide+fade entry animation.
/// Used when a new field is added to the builder list.
class SpringItemEntry extends StatefulWidget {
  const SpringItemEntry({super.key, required this.child});

  final Widget child;

  @override
  State<SpringItemEntry> createState() => _SpringItemEntryState();
}

class _SpringItemEntryState extends State<SpringItemEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: OrgDurations.overlay);
    final curved = CurvedAnimation(parent: _ctrl, curve: OrgCurves.spring);
    _fade = curved;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
