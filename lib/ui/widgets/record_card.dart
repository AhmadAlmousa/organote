import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/models.dart';
import '../theme/color_tokens.dart';
import '../theme/motion.dart';

class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.index,
    required this.record,
    required this.accent,
    required this.accentSoft,
    required this.fields,
    this.onCopyAll,
  });

  final int index;
  final NoteRecord record;
  final Color accent;
  final Color accentSoft;
  final List<Widget> fields;
  final VoidCallback? onCopyAll;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.02,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.label.isEmpty ? 'Record ${index + 1}' : record.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.02,
                    ),
                  ),
                ),
                _CopyAllButton(
                  record: record,
                  accent: accent,
                  palette: palette,
                  onCopied: onCopyAll,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Column(children: fields),
          ),
        ],
      ),
    );
  }
}

class _CopyAllButton extends StatefulWidget {
  const _CopyAllButton({
    required this.record,
    required this.accent,
    required this.palette,
    this.onCopied,
  });

  final NoteRecord record;
  final Color accent;
  final OrgPalette palette;
  final VoidCallback? onCopied;

  @override
  State<_CopyAllButton> createState() => _CopyAllButtonState();
}

class _CopyAllButtonState extends State<_CopyAllButton> {
  bool _just = false;

  Future<void> _copyAll() async {
    final lines = <String>[];
    final label = widget.record.label.isEmpty ? 'Record' : widget.record.label;
    lines.add(label);
    widget.record.values.forEach((key, value) {
      lines.add('  $key: $value');
    });
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    widget.onCopied?.call();
    if (!mounted) return;
    setState(() => _just = true);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _just = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _copyAll,
      child: AnimatedContainer(
        duration: OrgDurations.tap,
        curve: OrgCurves.spring,
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _just ? widget.accent : widget.palette.bgSecondary,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: _just ? widget.accent : widget.palette.border,
          ),
        ),
        child: Icon(
          _just ? Icons.check_rounded : Icons.content_copy_rounded,
          size: 14,
          color: _just ? widget.palette.onAccent : widget.palette.textSecondary,
        ),
      ),
    );
  }
}
