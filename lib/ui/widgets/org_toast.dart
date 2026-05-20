import 'package:flutter/material.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';

void showOrgToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_rounded,
  Duration duration = const Duration(milliseconds: 1700),
  Color? background,
  Color? foreground,
}) {
  final palette = OrgPaletteScope.of(context);
  final bg = background ?? palette.accent;
  final fg = foreground ?? palette.onAccent;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.only(
        left: 0,
        right: 0,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      content: Center(
        child: _ToastBubble(
          message: message,
          icon: icon,
          background: bg,
          foreground: fg,
        ),
      ),
    ),
  );
}

class _ToastBubble extends StatefulWidget {
  const _ToastBubble({
    required this.message,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  State<_ToastBubble> createState() => _ToastBubbleState();
}

class _ToastBubbleState extends State<_ToastBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: OrgDurations.toggle,
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final eased = OrgCurves.spring.transform(_anim.value);
        return Transform.translate(
          offset: Offset(0, (1 - eased) * 18),
          child: Opacity(opacity: _anim.value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: widget.background,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: widget.background.withAlpha(110),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 16, color: widget.foreground),
            const SizedBox(width: 6),
            Text(
              widget.message,
              style: TextStyle(
                color: widget.foreground,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
