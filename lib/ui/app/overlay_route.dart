import 'package:flutter/material.dart';

import '../theme/motion.dart';

class OrgOverlayRoute<T> extends PageRoute<T> {
  OrgOverlayRoute({required this.builder, bool fullscreenDialog = true})
    : _fullscreenDialog = fullscreenDialog;

  final WidgetBuilder builder;
  final bool _fullscreenDialog;

  @override
  bool get fullscreenDialog => _fullscreenDialog;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => OrgDurations.overlay;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: OrgCurves.sheet);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curved);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(position: slide, child: child),
    );
  }
}
