import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/color_tokens.dart';
import '../theme/motion.dart';
import 'copy_ripple.dart';

class CopyField extends StatefulWidget {
  const CopyField({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.accentSoft,
    this.mono = false,
    this.mask = false,
    this.onCopied,
  });

  final String label;
  final String value;
  final Color accent;
  final Color accentSoft;
  final bool mono;
  final bool mask;
  final ValueChanged<String>? onCopied;

  @override
  State<CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<CopyField> {
  final CopyRippleController _ripple = CopyRippleController();
  bool _copied = false;
  bool _reveal = false;
  bool _hover = false;
  bool _down = false;
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
    _timer = Timer(const Duration(milliseconds: 1400), () {
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
    final borderColor = _hover ? widget.accent : palette.border;
    final scale = _down ? 0.985 : 1.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (details) {
          setState(() => _down = false);
          _handleTap(details.localPosition);
        },
        child: AnimatedScale(
          scale: scale,
          duration: OrgDurations.tap,
          curve: OrgCurves.spring,
          child: AnimatedContainer(
            duration: OrgDurations.tap,
            curve: OrgCurves.spring,
            decoration: BoxDecoration(
              color: _hover ? palette.surfaceHigh : palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: CopyRippleOverlay(
              controller: _ripple,
              color: widget.accent,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.06,
                              color: palette.textTertiary,
                            ),
                          ),
                        ),
                        if (widget.mask) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _reveal = !_reveal),
                            child: Text(
                              _reveal ? 'HIDE' : 'SHOW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.06,
                                color: _reveal
                                    ? widget.accent
                                    : palette.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              size: 14,
                              color: _copied
                                  ? widget.accent
                                  : palette.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _copied ? 'COPIED' : 'TAP TO COPY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.06,
                                color: _copied
                                    ? widget.accent
                                    : palette.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.012,
                        height: 1.25,
                        color: palette.text,
                        fontFamily: widget.mono ? 'JetBrainsMono' : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
