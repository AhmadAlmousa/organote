import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/color_tokens.dart';
import '../theme/density.dart';
import '../theme/motion.dart';
import '../util/category_color.dart';
import '../util/relative_time.dart';

class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.template,
    required this.category,
    required this.onOpen,
    required this.onTogglePin,
    required this.onToggleFavorite,
  });

  final Note note;
  final Template? template;
  final Category? category;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleFavorite;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    final hue = widget.category != null
        ? hueOfCategory(widget.category!, fallbackHue: palette.accentHue)
        : palette.accentHue;
    final accent = accentForHue(hue);
    final soft = softForHue(hue, 0.18);

    final recordCount = widget.note.records.length;
    final translateY = _hover && !_down ? -2.0 : 0.0;
    final scale = _down ? 0.985 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: OrgDurations.hover,
          curve: OrgCurves.spring,
          transform: Matrix4.identity()
            ..translateByDouble(0, translateY, 0, 1)
            ..scaleByDouble(scale, scale, 1, 1),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(compact ? 14 : 18),
            border: Border.all(color: palette.border),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: palette.shadowSoft,
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 10 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TemplateBadge(
                    name: widget.template?.name ?? 'No template',
                    accent: accent,
                    soft: soft,
                  ),
                  const Spacer(),
                  _ActionIcon(
                    icon: widget.note.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    active: widget.note.isPinned,
                    accent: accent,
                    muted: palette.textTertiary,
                    onTap: widget.onTogglePin,
                  ),
                  const SizedBox(width: 2),
                  _ActionIcon(
                    icon: widget.note.isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    active: widget.note.isFavorite,
                    accent: palette.accent,
                    muted: palette.textTertiary,
                    onTap: widget.onToggleFavorite,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.note.title.isEmpty ? 'Untitled note' : widget.note.title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: palette.text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _CategoryPill(
                    category: widget.category,
                    accent: accent,
                    soft: soft,
                  ),
                  if (recordCount > 1)
                    _RecordBadge(count: recordCount, palette: palette),
                  Text(
                    formatRelativeTime(widget.note.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textTertiary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              if (widget.note.tags.isNotEmpty) ...[
                const SizedBox(height: 7),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in widget.note.tags)
                      _TagChip(label: tag, palette: palette),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateBadge extends StatelessWidget {
  const _TemplateBadge({
    required this.name,
    required this.accent,
    required this.soft,
  });

  final String name;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            boxShadow: [BoxShadow(color: soft, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.06,
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.category,
    required this.accent,
    required this.soft,
  });

  final Category? category;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    final name = category?.name ?? 'Uncategorized';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.02,
        ),
      ),
    );
  }
}

class _RecordBadge extends StatelessWidget {
  const _RecordBadge({required this.count, required this.palette});

  final int count;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count records',
        style: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.palette});

  final String label;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '#$label',
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: palette.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionIcon extends StatefulWidget {
  const _ActionIcon({
    required this.icon,
    required this.active,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  @override
  State<_ActionIcon> createState() => _ActionIconState();
}

class _ActionIconState extends State<_ActionIcon> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _hover ? 1.15 : 1.0,
          duration: OrgDurations.press,
          curve: OrgCurves.spring,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.active ? widget.accent : widget.muted,
            ),
          ),
        ),
      ),
    );
  }
}
