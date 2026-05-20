import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../domain/models/models.dart';
import '../../theme/color_tokens.dart';
import '../../theme/motion.dart';
import 'form_field_host.dart';

class DateFieldImpl extends StatefulWidget {
  const DateFieldImpl({
    super.key,
    required this.field,
    required this.controller,
    required this.onChanged,
    this.error,
    this.accent,
  });

  final TemplateField field;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? error;
  final Color? accent;

  @override
  State<DateFieldImpl> createState() => _DateFieldImplState();
}

class _DateFieldImplState extends State<DateFieldImpl> {
  static final DateTime _firstSupportedDate = DateTime(1937, 3, 14);
  static final DateTime _lastSupportedDate = DateTime(2077, 11, 16);

  Future<void> _pickDate() async {
    final initial = _clampDate(
      _dateFromValue(widget.controller.text) ?? DateTime.now(),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _firstSupportedDate,
      lastDate: _lastSupportedDate,
      builder: (context, child) {
        final palette = OrgPaletteScope.of(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: widget.accent ?? palette.accent,
              surface: palette.surface,
              onSurface: palette.text,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (!mounted || picked == null) return;
    _setDate(picked);
  }

  void _setToday() {
    _setDate(_clampDate(DateTime.now()));
  }

  void _setDate(DateTime date) {
    widget.controller.text = _formatStorageValue(date);
    widget.onChanged();
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final accent = widget.accent ?? palette.accent;
    final hintParts = <String>[
      if (widget.field.hint != null && widget.field.hint!.isNotEmpty)
        widget.field.hint!,
      _modeHint(widget.field),
    ];
    return FormFieldHost(
      label: widget.field.label,
      required: widget.field.isRequired,
      accent: widget.accent,
      error: widget.error,
      hint: hintParts.join(' · '),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final raw = value.text.trim();
          final selectedDate = _dateFromValue(raw);
          final primary = _primaryDisplay(raw, selectedDate);
          final secondary = _secondaryDisplay(selectedDate);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primary,
                          style: TextStyle(
                            color: raw.isEmpty
                                ? palette.textTertiary
                                : palette.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            fontFamily: raw.isEmpty ? null : 'JetBrainsMono',
                          ),
                        ),
                        if (secondary != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondary,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DateActionChip(
                    label: 'Today',
                    icon: Icons.today_rounded,
                    accent: accent,
                    palette: palette,
                    onTap: _setToday,
                  ),
                  _DateActionChip(
                    label: raw.isEmpty ? 'Pick date' : 'Change',
                    icon: Icons.edit_calendar_rounded,
                    accent: accent,
                    palette: palette,
                    onTap: _pickDate,
                  ),
                  if (raw.isNotEmpty)
                    _DateActionChip(
                      label: 'Clear',
                      icon: Icons.close_rounded,
                      accent: palette.textSecondary,
                      palette: palette,
                      onTap: _clear,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _primaryDisplay(String raw, DateTime? selectedDate) {
    if (raw.isEmpty) return 'Pick date';
    if (selectedDate == null) return raw;
    if (widget.field.calendarMode == CalendarMode.dual &&
        widget.field.primaryCalendar == CalendarSystem.hijri) {
      return '${_formatHijri(selectedDate)} H';
    }
    if (widget.field.calendarMode == CalendarMode.hijri) {
      return '${_formatHijri(selectedDate)} H';
    }
    return _formatGregorian(selectedDate);
  }

  String? _secondaryDisplay(DateTime? selectedDate) {
    if (selectedDate == null ||
        widget.field.calendarMode != CalendarMode.dual) {
      return null;
    }
    if (widget.field.primaryCalendar == CalendarSystem.hijri) {
      return _formatGregorian(selectedDate);
    }
    return '${_formatHijri(selectedDate)} H';
  }

  String _formatStorageValue(DateTime date) {
    final gregorian = _formatGregorian(date);
    final hijri = '${_formatHijri(date)} H';
    return switch (widget.field.calendarMode) {
      CalendarMode.gregorian => gregorian,
      CalendarMode.hijri => hijri,
      CalendarMode.dual => '$gregorian | $hijri',
    };
  }

  DateTime? _dateFromValue(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split('|').map((part) => part.trim()).toList();
    if (widget.field.calendarMode == CalendarMode.hijri) {
      return _parseHijri(parts.first);
    }
    if (widget.field.calendarMode == CalendarMode.dual) {
      String? gregorian;
      for (final part in parts) {
        if (!part.toUpperCase().contains('H')) {
          gregorian = part;
          break;
        }
      }
      return _parseGregorian(gregorian ?? parts.first) ??
          _parseHijri(parts.length > 1 ? parts[1] : parts.first);
    }
    return _parseGregorian(parts.first);
  }

  DateTime _clampDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized.isBefore(_firstSupportedDate)) return _firstSupportedDate;
    if (normalized.isAfter(_lastSupportedDate)) return _lastSupportedDate;
    return normalized;
  }

  DateTime? _parseGregorian(String raw) {
    final parts = _parseDateParts(raw);
    if (parts == null) return null;
    try {
      final date = DateTime(parts.year, parts.month, parts.day);
      if (date.year == parts.year &&
          date.month == parts.month &&
          date.day == parts.day) {
        return date;
      }
    } on ArgumentError {
      return null;
    }
    return null;
  }

  DateTime? _parseHijri(String raw) {
    final parts = _parseDateParts(raw.replaceAll(RegExp('[Hh]'), ''));
    if (parts == null) return null;
    try {
      return HijriCalendar().hijriToGregorian(
        parts.year,
        parts.month,
        parts.day,
      );
    } on Object {
      return null;
    }
  }

  _DateParts? _parseDateParts(String raw) {
    final pieces = raw.trim().split(RegExp(r'[-/]'));
    if (pieces.length != 3) return null;
    final numbers = pieces.map(int.tryParse).toList();
    if (numbers.any((number) => number == null)) return null;
    final first = numbers[0]!;
    final second = numbers[1]!;
    final third = numbers[2]!;
    if (pieces[0].length == 4) {
      return _DateParts(year: first, month: second, day: third);
    }
    return _DateParts(year: third, month: second, day: first);
  }

  String _formatGregorian(DateTime date) {
    return '${_two(date.day)}-${_two(date.month)}-${date.year.toString().padLeft(4, '0')}';
  }

  String _formatHijri(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    return '${_two(hijri.hDay)}-${_two(hijri.hMonth)}-${hijri.hYear.toString().padLeft(4, '0')}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _modeHint(TemplateField field) {
    return switch (field.calendarMode) {
      CalendarMode.gregorian => 'Gregorian date',
      CalendarMode.hijri => 'Hijri date',
      CalendarMode.dual => 'Stored as Gregorian | Hijri H',
    };
  }
}

class _DateActionChip extends StatelessWidget {
  const _DateActionChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final OrgPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.spring,
        height: 32,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateParts {
  const _DateParts({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;
}
