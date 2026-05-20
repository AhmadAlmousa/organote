import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/color_tokens.dart';
import '../theme/motion.dart';
import '../util/category_color.dart';
import '../util/oklch.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedPath,
    required this.onSelect,
    required this.onCreate,
  });

  final List<Category> categories;
  final String selectedPath;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String name, String colorHex) onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final chips = <Widget>[
      _Chip(
        label: 'Uncategorized',
        active: selectedPath.isEmpty,
        hueColor: palette.accent,
        softColor: palette.accentSoft,
        onTap: () => onSelect(''),
      ),
      for (final category in categories)
        _Chip(
          label: category.name,
          active: selectedPath == category.path,
          hueColor: accentForHue(
            hueOfCategory(category, fallbackHue: palette.accentHue),
          ),
          softColor: softForHue(
            hueOfCategory(category, fallbackHue: palette.accentHue),
            0.2,
          ),
          onTap: () => onSelect(category.path),
        ),
      _AddChip(palette: palette, onTap: () => _openCreateDialog(context)),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) => Center(child: chips[index]),
      ),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final palette = OrgPaletteScope.of(context);
    final controller = TextEditingController();
    double hue = palette.accentHue;
    final result = await showModalBottomSheet<_NewCategoryResult>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) {
            final accent = accentForHue(hue);
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 14),
                  Text(
                    'New category',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: palette.text,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Categories map directly to folders on disk and tint the chips.',
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      10,
                      10,
                      10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.bgSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      cursorColor: accent,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Servers, Personal, Travel…',
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'COLOR',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.06,
                          color: palette.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withAlpha(80),
                              blurRadius: 12,
                              spreadRadius: -3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: <Color>[
                                  Color(0xFFFF6B6B),
                                  Color(0xFFFFD166),
                                  Color(0xFF06D6A0),
                                  Color(0xFF118AB2),
                                  Color(0xFF9D4EDD),
                                  Color(0xFFFF6B6B),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(sheetContext).copyWith(
                            trackHeight: 6,
                            thumbColor: accent,
                            overlayColor: accent.withAlpha(40),
                            activeTrackColor: Colors.transparent,
                            inactiveTrackColor: Colors.transparent,
                          ),
                          child: Slider(
                            min: 0,
                            max: 360,
                            value: hue,
                            onChanged: (v) => setState(() => hue = v),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.text,
                            side: BorderSide(color: palette.borderStrong),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: controller.text.trim().isEmpty
                              ? null
                              : () => Navigator.of(sheetContext).pop(
                                  _NewCategoryResult(
                                    name: controller.text.trim(),
                                    hue: hue,
                                  ),
                                ),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: palette.onAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (result == null) return;
    await onCreate(result.name, _hexFromHue(result.hue));
  }

  String _hexFromHue(double hue) {
    final color = oklchToColor(0.82, 0.16, hue);
    final argb = color.toARGB32();
    return '#${((argb >> 16) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${((argb >> 8) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${(argb & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase()}'
        .toUpperCase();
  }
}

class _NewCategoryResult {
  const _NewCategoryResult({required this.name, required this.hue});

  final String name;
  final double hue;
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.hueColor,
    required this.softColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color hueColor;
  final Color softColor;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final bg = widget.active
        ? widget.softColor
        : _hover
        ? palette.surfaceHigh
        : palette.surface;
    final fg = widget.active
        ? (palette.brightness == Brightness.dark
              ? widget.hueColor
              : palette.onAccent)
        : palette.textSecondary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.hueColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddChip extends StatefulWidget {
  const _AddChip({required this.palette, required this.onTap});

  final OrgPalette palette;
  final VoidCallback onTap;

  @override
  State<_AddChip> createState() => _AddChipState();
}

class _AddChipState extends State<_AddChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hover ? widget.palette.surfaceHigh : widget.palette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: widget.palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 14,
                color: widget.palette.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Add',
                style: TextStyle(
                  color: widget.palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
