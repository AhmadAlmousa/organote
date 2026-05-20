import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/color_tokens.dart';
import '../theme/motion.dart';

Future<TemplateFieldType?> showFieldTypePicker(BuildContext context) {
  final palette = OrgPaletteScope.of(context);
  return showModalBottomSheet<TemplateFieldType>(
    context: context,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => const _Sheet(),
  );
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  static const List<(TemplateFieldType, IconData, String)> _cells = [
    (TemplateFieldType.text, Icons.title_rounded, 'Text'),
    (TemplateFieldType.number, Icons.tag_rounded, 'Number'),
    (TemplateFieldType.date, Icons.calendar_today_rounded, 'Date'),
    (TemplateFieldType.boolean, Icons.toggle_on_rounded, 'Boolean'),
    (TemplateFieldType.dropdown, Icons.list_rounded, 'Dropdown'),
    (TemplateFieldType.password, Icons.lock_rounded, 'Password'),
    (TemplateFieldType.url, Icons.link_rounded, 'URL'),
    (TemplateFieldType.ip, Icons.router_rounded, 'IP Address'),
    (TemplateFieldType.regex, Icons.code_rounded, 'Regex'),
    (TemplateFieldType.image, Icons.image_rounded, 'Image'),
    (TemplateFieldType.customLabel, Icons.label_rounded, 'Label'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Field type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.18,
              children: _cells
                  .map(
                    (cell) => _Cell(
                      icon: cell.$2,
                      label: cell.$3,
                      onTap: () => Navigator.of(context).pop(cell.$1),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatefulWidget {
  const _Cell({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1.0,
        duration: OrgDurations.tap,
        curve: OrgCurves.spring,
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: palette.accent, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
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

IconData fieldTypeIcon(TemplateFieldType type) {
  return switch (type) {
    TemplateFieldType.text => Icons.title_rounded,
    TemplateFieldType.number => Icons.tag_rounded,
    TemplateFieldType.date => Icons.calendar_today_rounded,
    TemplateFieldType.boolean => Icons.toggle_on_rounded,
    TemplateFieldType.dropdown => Icons.list_rounded,
    TemplateFieldType.password => Icons.lock_rounded,
    TemplateFieldType.url => Icons.link_rounded,
    TemplateFieldType.ip => Icons.router_rounded,
    TemplateFieldType.regex => Icons.code_rounded,
    TemplateFieldType.image => Icons.image_rounded,
    TemplateFieldType.customLabel => Icons.label_rounded,
  };
}

String fieldTypeLabel(TemplateFieldType type) {
  return switch (type) {
    TemplateFieldType.text => 'Text',
    TemplateFieldType.number => 'Number',
    TemplateFieldType.date => 'Date',
    TemplateFieldType.boolean => 'Boolean',
    TemplateFieldType.dropdown => 'Dropdown',
    TemplateFieldType.password => 'Password',
    TemplateFieldType.url => 'URL',
    TemplateFieldType.ip => 'IP Address',
    TemplateFieldType.regex => 'Regex',
    TemplateFieldType.image => 'Image',
    TemplateFieldType.customLabel => 'Label',
  };
}
