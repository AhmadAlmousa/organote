import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/color_tokens.dart';
import '../theme/density.dart';
import '../theme/motion.dart';
import '../util/relative_time.dart';

class TemplateCard extends StatefulWidget {
  const TemplateCard({
    super.key,
    required this.template,
    required this.notes,
    required this.onShowNotes,
    required this.onCreateNote,
    required this.onEdit,
  });

  final Template template;
  final List<Note> notes;
  final void Function(Template template, List<Note> notes) onShowNotes;
  final ValueChanged<Template> onCreateNote;
  final ValueChanged<Template> onEdit;

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final compact = OrgDensity.of(context) == OrgDensityLevel.compact;
    final template = widget.template;
    final used = widget.notes.isNotEmpty;
    final fieldPreview = template.fields
        .take(4)
        .map((field) => field.label)
        .where((label) => label.trim().isNotEmpty)
        .join(' / ');
    final requiredCount = template.fields
        .where((field) => field.isRequired)
        .length;
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
        onTap: () => widget.onEdit(template),
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
          padding: EdgeInsets.all(compact ? 12 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TemplateAvatar(template: template, used: used),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            template.name.isEmpty
                                ? 'Untitled template'
                                : template.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: palette.text,
                                  height: 1.18,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LayoutPill(layout: template.layout),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      fieldPreview.isEmpty ? 'No fields yet' : fieldPreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetricPill(
                          icon: Icons.view_column_rounded,
                          label:
                              '${template.fields.length} field${template.fields.length == 1 ? '' : 's'}',
                        ),
                        _MetricPill(
                          icon: Icons.rule_rounded,
                          label: '$requiredCount required',
                        ),
                        _MetricPill(
                          icon: Icons.history_rounded,
                          label: formatRelativeTime(template.updatedAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MiniAction(
                          icon: used
                              ? Icons.article_outlined
                              : Icons.note_add_outlined,
                          label: used
                              ? '${widget.notes.length} notes'
                              : 'Create note',
                          active: used,
                          onTap: () => used
                              ? widget.onShowNotes(template, widget.notes)
                              : widget.onCreateNote(template),
                        ),
                        const SizedBox(width: 8),
                        _MiniAction(
                          icon: Icons.add_rounded,
                          label: 'Create',
                          active: false,
                          onTap: () => widget.onCreateNote(template),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateAvatar extends StatelessWidget {
  const _TemplateAvatar({required this.template, required this.used});

  final Template template;
  final bool used;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: used ? palette.accentSoft : palette.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: used ? palette.accent.withAlpha(80) : palette.border,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        template.icon ?? _initialFor(template.name),
        style: TextStyle(
          color: used ? palette.accent : palette.textSecondary,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _LayoutPill extends StatelessWidget {
  const _LayoutPill({required this.layout});

  final TemplateLayout layout;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_layoutIcon(layout), size: 12, color: palette.textTertiary),
          const SizedBox(width: 4),
          Text(
            layout.name,
            style: TextStyle(
              color: palette.textTertiary,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  IconData _layoutIcon(TemplateLayout layout) {
    return switch (layout) {
      TemplateLayout.cards => Icons.view_agenda_rounded,
      TemplateLayout.table => Icons.table_rows_rounded,
      TemplateLayout.grid => Icons.grid_view_rounded,
    };
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: palette.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAction extends StatefulWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_MiniAction> createState() => _MiniActionState();
}

class _MiniActionState extends State<_MiniAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final bg = widget.active
        ? palette.accentSoft
        : (_hover ? palette.surfaceHigh : palette.bgSecondary);
    final fg = widget.active ? palette.accent : palette.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.active ? Colors.transparent : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initialFor(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '#';
  return trimmed.characters.first.toUpperCase();
}
