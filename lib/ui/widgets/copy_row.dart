import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';
import 'copy_ripple.dart';

class CopyRow extends StatefulWidget {
  const CopyRow({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.accentSoft,
    this.mono = false,
    this.mask = false,
    this.onCopied,
    this.last = false,
  });

  final String label;
  final String value;
  final Color accent;
  final Color accentSoft;
  final bool mono;
  final bool mask;
  final ValueChanged<String>? onCopied;
  final bool last;

  @override
  State<CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<CopyRow> {
  final CopyRippleController _ripple = CopyRippleController();
  bool _copied = false;
  bool _reveal = false;
  bool _hover = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleTap(Offset position) async {
    if (widget.value.isEmpty) return;
    _ripple.trigger(position);
    await Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    widget.onCopied?.call(widget.value);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final displayValue = widget.value.isEmpty
        ? '—'
        : widget.mask && !_reveal
        ? '•' * widget.value.length.clamp(0, 14)
        : widget.value;
    final backgroundColor = _copied
        ? widget.accentSoft
        : _hover
        ? palette.bgSecondary
        : Colors.transparent;
    return MouseRegion(
      cursor: widget.value.isEmpty
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details.localPosition),
        child: AnimatedContainer(
          duration: OrgDurations.tap,
          curve: OrgCurves.spring,
          margin: const EdgeInsetsDirectional.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: CopyRippleOverlay(
            controller: _ripple,
            color: widget.accent,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.06,
                            color: palette.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayValue,
                          softWrap: true,
                          style: TextStyle(
                            fontSize: widget.mono ? 14 : 15,
                            fontWeight: widget.mono
                                ? FontWeight.w500
                                : FontWeight.w600,
                            fontFamily: widget.mono ? 'JetBrainsMono' : null,
                            letterSpacing: widget.mono ? -0.01 : -0.012,
                            color: palette.text,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.mask)
                    _RevealButton(
                      revealed: _reveal,
                      accent: widget.accent,
                      muted: palette.textTertiary,
                      onTap: () => setState(() => _reveal = !_reveal),
                    ),
                  const SizedBox(width: 8),
                  _CopyIndicator(
                    copied: _copied,
                    accent: widget.accent,
                    onAccent: palette.onAccent,
                    background: palette.bgSecondary,
                    muted: palette.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({
    required this.revealed,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final bool revealed;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        child: Text(
          revealed ? 'HIDE' : 'SHOW',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.06,
            color: revealed ? accent : muted,
          ),
        ),
      ),
    );
  }
}

class _CopyIndicator extends StatelessWidget {
  const _CopyIndicator({
    required this.copied,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.muted,
  });

  final bool copied;
  final Color accent;
  final Color onAccent;
  final Color background;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: copied ? 1.1 : 1.0,
      duration: OrgDurations.toggle,
      curve: OrgCurves.spring,
      child: AnimatedContainer(
        duration: OrgDurations.tap,
        curve: OrgCurves.spring,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: copied ? accent : background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 14,
          color: copied ? onAccent : muted,
        ),
      ),
    );
  }
}
