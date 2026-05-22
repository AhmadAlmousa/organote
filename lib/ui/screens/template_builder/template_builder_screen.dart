import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/repositories/repositories.dart';
import '../../state/app_providers.dart';
import '../../state/library_provider.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../theme/motion.dart';
import '../../util/category_color.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/emoji_picker_button.dart';
import '../../widgets/field_type_picker_sheet.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_toast.dart';
import '../../widgets/reorderable_field_list.dart';

String _randomId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
}

// ---------------------------------------------------------------------------
// Draft model
// ---------------------------------------------------------------------------

class _FieldDraft {
  _FieldDraft({
    String? id,
    this.label = '',
    this.type = TemplateFieldType.text,
    this.isRequired = false,
    this.hint,
    this.multiline = false,
    this.minLength,
    this.maxLength,
    this.digits,
    this.min,
    this.max,
    List<String>? options,
    this.regex,
    this.calendarMode = CalendarMode.gregorian,
    this.primaryCalendar = CalendarSystem.gregorian,
    this.expanded = false,
    this.isNew = false,
  }) : id = id ?? _randomId(),
       labelController = TextEditingController(text: label),
       hintController = TextEditingController(text: hint ?? ''),
       regexController = TextEditingController(text: regex ?? ''),
       options = options ?? <String>[];

  final String id;
  String label;
  TemplateFieldType type;
  bool isRequired;
  String? hint;
  bool multiline;
  int? minLength;
  int? maxLength;
  int? digits;
  num? min;
  num? max;
  final List<String> options;
  String? regex;
  CalendarMode calendarMode;
  CalendarSystem primaryCalendar;
  bool expanded;
  bool isNew;

  final TextEditingController labelController;
  final TextEditingController hintController;
  final TextEditingController regexController;

  void dispose() {
    labelController.dispose();
    hintController.dispose();
    regexController.dispose();
  }

  TemplateField toField() => TemplateField(
    id: id,
    label: label.isEmpty ? 'Untitled' : label,
    type: type,
    isRequired: isRequired,
    hint: hint?.isEmpty == true ? null : hint,
    multiline: multiline,
    minLength: minLength,
    maxLength: maxLength,
    digits: digits,
    min: min,
    max: max,
    options: List<String>.from(options),
    regex: regex?.isEmpty == true ? null : regex,
    calendarMode: calendarMode,
    primaryCalendar: primaryCalendar,
  );

  static _FieldDraft fromField(TemplateField f) => _FieldDraft(
    id: f.id,
    label: f.label,
    type: f.type,
    isRequired: f.isRequired,
    hint: f.hint,
    multiline: f.multiline,
    minLength: f.minLength,
    maxLength: f.maxLength,
    digits: f.digits,
    min: f.min,
    max: f.max,
    options: List<String>.from(f.options),
    regex: f.regex,
    calendarMode: f.calendarMode,
    primaryCalendar: f.primaryCalendar,
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TemplateBuilderScreen extends ConsumerStatefulWidget {
  const TemplateBuilderScreen({
    super.key,
    this.templateId,
    this.onClose,
    this.onSaved,
  });

  final String? templateId;
  final VoidCallback? onClose;
  final ValueChanged<Template>? onSaved;

  @override
  ConsumerState<TemplateBuilderScreen> createState() =>
      _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState extends ConsumerState<TemplateBuilderScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _icon;
  TemplateLayout _layout = TemplateLayout.cards;
  String _categoryPath = '';
  final List<_FieldDraft> _fields = [];
  bool _saving = false;
  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _seed(LibrarySnapshot snapshot) {
    _seeded = true;
    if (widget.templateId == null) return;
    final tmpl = snapshot.templates
        .where((t) => t.id == widget.templateId)
        .firstOrNull;
    if (tmpl == null) return;
    _nameController.text = tmpl.name;
    _icon = tmpl.icon;
    _layout = tmpl.layout;
    _categoryPath = tmpl.defaultCategory ?? '';
    _fields.addAll(tmpl.fields.map(_FieldDraft.fromField));
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showOrgToast(context, message: 'Template needs a name');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(templateRepositoryProvider);
      final saved = await repo.saveTemplate(
        TemplateInput(
          id: widget.templateId,
          name: name,
          icon: _icon,
          layout: _layout,
          defaultCategory: _categoryPath.isEmpty ? null : _categoryPath,
          fields: _fields.map((f) => f.toField()).toList(),
        ),
      );
      if (!mounted) return;
      widget.onSaved?.call(saved);
      _close();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showOrgToast(
          context,
          message: 'Save failed',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _close() {
    if (!mounted) return;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else if (_saving) {
      setState(() => _saving = false);
    }
  }

  Future<void> _createCategory(String name, String colorHex) async {
    final repo = ref.read(categoryRepositoryProvider);
    final category = await repo.saveCategory(
      Category(
        path: name.toLowerCase().replaceAll(' ', '-'),
        name: name,
        colorHex: colorHex,
      ),
    );
    setState(() => _categoryPath = category.path);
  }

  Future<void> _addField() async {
    final type = await showFieldTypePicker(context);
    if (type == null || !mounted) return;
    setState(() {
      _fields.add(_FieldDraft(type: type, expanded: true, isNew: true));
    });
  }

  void _removeField(int index) {
    final draft = _fields[index];
    draft.dispose();
    setState(() => _fields.removeAt(index));
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _fields.removeAt(oldIndex);
      _fields.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final snapshot = ref.watch(librarySnapshotProvider);
    if (!_seeded) _seed(snapshot);

    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    final hPad = compact ? 12.0 : 18.0;
    final catMatch = _categoryPath.isNotEmpty
        ? snapshot.categories.where((c) => c.path == _categoryPath).firstOrNull
        : null;
    final categoryHue = catMatch != null
        ? hueOfCategory(catMatch, fallbackHue: palette.accentHue)
        : palette.accentHue;
    final accent = accentForHue(categoryHue);
    final accentSoft = softForHue(categoryHue, 0.18);

    return PopScope<Object?>(
      canPop: widget.onClose == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: palette.bg,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _AppBar(
                  saving: _saving,
                  accent: accent,
                  isEdit: widget.templateId != null,
                  onBack: _close,
                  onSave: _save,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(hPad, 8, hPad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderRow(
                        icon: _icon,
                        nameController: _nameController,
                        accent: accent,
                        accentSoft: accentSoft,
                        onIconPicked: (v) => setState(() => _icon = v),
                        onNameChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _LayoutSegmented(
                        value: _layout,
                        accent: accent,
                        accentSoft: accentSoft,
                        onChanged: (v) => setState(() => _layout = v),
                      ),
                      const SizedBox(height: 12),
                      CategorySelector(
                        categories: snapshot.categories,
                        selectedPath: _categoryPath,
                        onSelect: (v) => setState(() => _categoryPath = v),
                        onCreate: _createCategory,
                      ),
                      const SizedBox(height: 24),
                      _SectionLabel(label: 'Fields (${_fields.length})'),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              if (_fields.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(hPad, 0, hPad, 0),
                    child: _EmptyFields(
                      accent: accent,
                      accentSoft: accentSoft,
                      onAdd: _addField,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(hPad, 0, hPad, 0),
                  sliver: SliverToBoxAdapter(
                    child: ReorderableFieldList(
                      itemCount: _fields.length,
                      onReorder: _reorder,
                      itemBuilder: (context, i) {
                        final draft = _fields[i];
                        final child = _FieldRow(
                          key: ValueKey(draft.id),
                          draft: draft,
                          accent: accent,
                          accentSoft: accentSoft,
                          onDelete: () => _removeField(i),
                          onChanged: () => setState(() {}),
                        );
                        if (draft.isNew) {
                          draft.isNew = false;
                          return SpringItemEntry(
                            key: ValueKey('entry_${draft.id}'),
                            child: child,
                          );
                        }
                        return child;
                      },
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(hPad, 12, hPad, 0),
                  child: _AddFieldButton(
                    accent: accent,
                    accentSoft: accentSoft,
                    onTap: _addField,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _AppBar extends StatelessWidget {
  const _AppBar({
    required this.saving,
    required this.accent,
    required this.isEdit,
    required this.onBack,
    required this.onSave,
  });

  final bool saving;
  final Color accent;
  final bool isEdit;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 12, 0),
      child: Row(
        children: [
          OrgIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: onBack,
            tooltip: 'Back',
          ),
          const Spacer(),
          Text(
            isEdit ? 'Edit template' : 'New template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          saving
              ? SizedBox(
                  width: 38,
                  height: 38,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: accent,
                    ),
                  ),
                )
              : _SaveButton(accent: accent, onSave: onSave),
        ],
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.accent, required this.onSave});

  final Color accent;
  final VoidCallback onSave;

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onSave();
      },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: OrgDurations.tap,
        curve: OrgCurves.spring,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            'Save',
            style: TextStyle(
              color: palette.onAccent,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatefulWidget {
  const _HeaderRow({
    required this.icon,
    required this.nameController,
    required this.accent,
    required this.accentSoft,
    required this.onIconPicked,
    required this.onNameChanged,
  });

  final String? icon;
  final TextEditingController nameController;
  final Color accent;
  final Color accentSoft;
  final ValueChanged<String?> onIconPicked;
  final ValueChanged<String> onNameChanged;

  @override
  State<_HeaderRow> createState() => _HeaderRowState();
}

class _HeaderRowState extends State<_HeaderRow> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EmojiPickerButton(
          value: widget.icon,
          onPicked: widget.onIconPicked,
          size: 56,
          label: 'Template icon',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedContainer(
            duration: OrgDurations.toggle,
            curve: OrgCurves.spring,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _focused ? widget.accent : palette.border,
                width: _focused ? 1.4 : 1,
              ),
              boxShadow: [
                if (_focused)
                  BoxShadow(
                    color: widget.accentSoft,
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -6,
                  )
                else
                  BoxShadow(
                    color: palette.shadowSoft,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                    spreadRadius: -10,
                  ),
              ],
            ),
            child: TextField(
              controller: widget.nameController,
              focusNode: _focus,
              onChanged: widget.onNameChanged,
              cursorColor: widget.accent,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: 'Template name',
                hintStyle: TextStyle(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ),
        ),
      ],
    );
  }
}

class _LayoutSegmented extends StatelessWidget {
  const _LayoutSegmented({
    required this.value,
    required this.accent,
    required this.accentSoft,
    required this.onChanged,
  });

  final TemplateLayout value;
  final Color accent;
  final Color accentSoft;
  final ValueChanged<TemplateLayout> onChanged;

  static const _options = <_LayoutOption>[
    _LayoutOption(
      layout: TemplateLayout.cards,
      icon: Icons.dashboard_rounded,
      label: 'Cards',
      description: 'Stacked notes',
    ),
    _LayoutOption(
      layout: TemplateLayout.table,
      icon: Icons.table_rows_rounded,
      label: 'Table',
      description: 'Rows of records',
    ),
    _LayoutOption(
      layout: TemplateLayout.grid,
      icon: Icons.grid_view_rounded,
      label: 'Grid',
      description: 'Tile layout',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note layout',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.05,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < _options.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _LayoutTile(
                  option: _options[i],
                  active: value == _options[i].layout,
                  accent: accent,
                  accentSoft: accentSoft,
                  palette: palette,
                  onTap: () => onChanged(_options[i].layout),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LayoutOption {
  const _LayoutOption({
    required this.layout,
    required this.icon,
    required this.label,
    required this.description,
  });

  final TemplateLayout layout;
  final IconData icon;
  final String label;
  final String description;
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({
    required this.option,
    required this.active,
    required this.accent,
    required this.accentSoft,
    required this.palette,
    required this.onTap,
  });

  final _LayoutOption option;
  final bool active;
  final Color accent;
  final Color accentSoft;
  final OrgPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.spring,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: active ? accentSoft : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? accent.withAlpha(140) : palette.border,
            width: active ? 1.4 : 1,
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: accent.withAlpha(60),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              )
            else
              BoxShadow(
                color: palette.shadowSoft,
                blurRadius: 14,
                offset: const Offset(0, 6),
                spreadRadius: -12,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active ? accent : palette.bgSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                option.icon,
                size: 20,
                color: active ? palette.onAccent : palette.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              option.label,
              style: TextStyle(
                color: active ? accent : palette.text,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: palette.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        fontSize: 11.5,
      ),
    );
  }
}

class _EmptyFields extends StatelessWidget {
  const _EmptyFields({
    required this.accent,
    required this.accentSoft,
    required this.onAdd,
  });

  final Color accent;
  final Color accentSoft;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.add_rounded, color: accent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'Add first field',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFieldButton extends StatefulWidget {
  const _AddFieldButton({
    required this.accent,
    required this.accentSoft,
    required this.onTap,
  });

  final Color accent;
  final Color accentSoft;
  final VoidCallback onTap;

  @override
  State<_AddFieldButton> createState() => _AddFieldButtonState();
}

class _AddFieldButtonState extends State<_AddFieldButton> {
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
        scale: _down ? 0.97 : 1.0,
        duration: OrgDurations.tap,
        curve: OrgCurves.spring,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accentSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: widget.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Add field',
                style: TextStyle(
                  color: widget.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field row
// ---------------------------------------------------------------------------

class _FieldRow extends StatefulWidget {
  const _FieldRow({
    super.key,
    required this.draft,
    required this.accent,
    required this.accentSoft,
    required this.onDelete,
    required this.onChanged,
  });

  final _FieldDraft draft;
  final Color accent;
  final Color accentSoft;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  State<_FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends State<_FieldRow> {
  bool _deleteHover = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final palette = OrgPaletteScope.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.spring,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: d.expanded ? widget.accentSoft : palette.border,
          ),
        ),
        child: Column(
          children: [
            _FieldRowHeader(
              draft: d,
              accent: widget.accent,
              accentSoft: widget.accentSoft,
              deleteHover: _deleteHover,
              onToggleExpand: () {
                setState(() => d.expanded = !d.expanded);
                widget.onChanged();
              },
              onDeleteEnter: () => setState(() => _deleteHover = true),
              onDeleteExit: () => setState(() => _deleteHover = false),
              onDelete: widget.onDelete,
            ),
            AnimatedSize(
              duration: OrgDurations.sheet,
              curve: OrgCurves.sheet,
              child: d.expanded
                  ? _FieldRowOptions(
                      draft: d,
                      accent: widget.accent,
                      accentSoft: widget.accentSoft,
                      onChanged: () {
                        setState(() {});
                        widget.onChanged();
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRowHeader extends StatelessWidget {
  const _FieldRowHeader({
    required this.draft,
    required this.accent,
    required this.accentSoft,
    required this.deleteHover,
    required this.onToggleExpand,
    required this.onDeleteEnter,
    required this.onDeleteExit,
    required this.onDelete,
  });

  final _FieldDraft draft;
  final Color accent;
  final Color accentSoft;
  final bool deleteHover;
  final VoidCallback onToggleExpand;
  final VoidCallback onDeleteEnter;
  final VoidCallback onDeleteExit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final label = draft.label.isEmpty ? 'Untitled field' : draft.label;

    return GestureDetector(
      onTap: onToggleExpand,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 10, 12, 10),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: 0,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 8, 0),
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 18,
                  color: palette.textTertiary,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(fieldTypeIcon(draft.type), color: accent, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fieldTypeLabel(draft.type),
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (draft.isRequired)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsetsDirectional.only(end: 8),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            AnimatedRotation(
              turns: draft.expanded ? 0.5 : 0,
              duration: OrgDurations.toggle,
              curve: OrgCurves.spring,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            MouseRegion(
              onEnter: (_) => onDeleteEnter(),
              onExit: (_) => onDeleteExit(),
              child: GestureDetector(
                onTap: onDelete,
                child: AnimatedContainer(
                  duration: OrgDurations.tap,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: deleteHover
                        ? palette.danger.withAlpha(28)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: deleteHover ? palette.danger : palette.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field options (expanded section)
// ---------------------------------------------------------------------------

class _FieldRowOptions extends StatefulWidget {
  const _FieldRowOptions({
    required this.draft,
    required this.accent,
    required this.accentSoft,
    required this.onChanged,
  });

  final _FieldDraft draft;
  final Color accent;
  final Color accentSoft;
  final VoidCallback onChanged;

  @override
  State<_FieldRowOptions> createState() => _FieldRowOptionsState();
}

class _FieldRowOptionsState extends State<_FieldRowOptions> {
  final TextEditingController _newOptionController = TextEditingController();

  @override
  void dispose() {
    _newOptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final palette = OrgPaletteScope.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: palette.border, height: 1),
          const SizedBox(height: 14),
          _OptionsTextField(
            label: 'Label',
            controller: d.labelController,
            onChanged: (v) {
              d.label = v;
              widget.onChanged();
            },
            accent: widget.accent,
          ),
          const SizedBox(height: 10),
          _OptionsTextField(
            label: 'Hint / placeholder',
            controller: d.hintController,
            onChanged: (v) {
              d.hint = v;
              widget.onChanged();
            },
            accent: widget.accent,
          ),
          const SizedBox(height: 10),
          _RequiredToggle(
            value: d.isRequired,
            accent: widget.accent,
            accentSoft: widget.accentSoft,
            onChanged: (v) {
              setState(() => d.isRequired = v);
              widget.onChanged();
            },
          ),
          ..._typeOptions(context, d, palette),
        ],
      ),
    );
  }

  List<Widget> _typeOptions(
    BuildContext context,
    _FieldDraft d,
    OrgPalette palette,
  ) {
    return switch (d.type) {
      TemplateFieldType.text => [
        const SizedBox(height: 10),
        _BoolOption(
          label: 'Multiline',
          value: d.multiline,
          accent: widget.accent,
          accentSoft: widget.accentSoft,
          onChanged: (v) {
            setState(() => d.multiline = v);
            widget.onChanged();
          },
        ),
        const SizedBox(height: 10),
        _IntRangeRow(
          label1: 'Min length',
          label2: 'Max length',
          value1: d.minLength,
          value2: d.maxLength,
          accent: widget.accent,
          onChanged1: (v) {
            d.minLength = v;
            widget.onChanged();
          },
          onChanged2: (v) {
            d.maxLength = v;
            widget.onChanged();
          },
        ),
      ],
      TemplateFieldType.number => [
        const SizedBox(height: 10),
        _IntRangeRow(
          label1: 'Min',
          label2: 'Max',
          value1: d.min?.toInt(),
          value2: d.max?.toInt(),
          accent: widget.accent,
          onChanged1: (v) {
            d.min = v;
            widget.onChanged();
          },
          onChanged2: (v) {
            d.max = v;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 10),
        _SingleIntField(
          label: 'Decimal places',
          value: d.digits,
          accent: widget.accent,
          onChanged: (v) {
            d.digits = v;
            widget.onChanged();
          },
        ),
      ],
      TemplateFieldType.date => [
        const SizedBox(height: 10),
        _CalendarModeSelector(
          value: d.calendarMode,
          accent: widget.accent,
          accentSoft: widget.accentSoft,
          onChanged: (v) {
            setState(() => d.calendarMode = v);
            widget.onChanged();
          },
        ),
        if (d.calendarMode == CalendarMode.dual) ...[
          const SizedBox(height: 10),
          _PrimaryCalendarSelector(
            value: d.primaryCalendar,
            accent: widget.accent,
            accentSoft: widget.accentSoft,
            onChanged: (v) {
              setState(() => d.primaryCalendar = v);
              widget.onChanged();
            },
          ),
        ],
      ],
      TemplateFieldType.dropdown => [
        const SizedBox(height: 12),
        _DropdownOptionsEditor(
          options: d.options,
          accent: widget.accent,
          accentSoft: widget.accentSoft,
          newOptionController: _newOptionController,
          onAdd: (opt) {
            setState(() => d.options.add(opt));
            widget.onChanged();
          },
          onRemove: (i) {
            setState(() => d.options.removeAt(i));
            widget.onChanged();
          },
        ),
      ],
      TemplateFieldType.regex => [
        const SizedBox(height: 10),
        _OptionsTextField(
          label: 'Pattern',
          controller: d.regexController,
          onChanged: (v) {
            d.regex = v;
            widget.onChanged();
          },
          accent: widget.accent,
          monospace: true,
        ),
        const SizedBox(height: 10),
        _RegexTester(pattern: d.regex ?? ''),
      ],
      _ => [],
    };
  }
}

// ---------------------------------------------------------------------------
// Small option widgets
// ---------------------------------------------------------------------------

class _OptionsTextField extends StatelessWidget {
  const _OptionsTextField({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.accent,
    this.monospace = false,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final Color accent;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: palette.border),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: accent, width: 1.5),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: palette.text,
        fontFamily: monospace ? 'JetBrainsMono' : null,
        fontSize: 13.5,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
        border: border,
        enabledBorder: border,
        focusedBorder: focusBorder,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: palette.bgSecondary,
      ),
    );
  }
}

class _RequiredToggle extends StatelessWidget {
  const _RequiredToggle({
    required this.value,
    required this.accent,
    required this.accentSoft,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final Color accentSoft;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: OrgDurations.toggle,
            curve: OrgCurves.spring,
            width: 38,
            height: 22,
            decoration: BoxDecoration(
              color: value ? accent : palette.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: value ? Colors.transparent : palette.borderStrong,
              ),
            ),
            child: AnimatedAlign(
              duration: OrgDurations.toggle,
              curve: OrgCurves.spring,
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? palette.onAccent : palette.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Required',
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoolOption extends StatelessWidget {
  const _BoolOption({
    required this.label,
    required this.value,
    required this.accent,
    required this.accentSoft,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color accent;
  final Color accentSoft;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: OrgDurations.toggle,
            curve: OrgCurves.spring,
            width: 38,
            height: 22,
            decoration: BoxDecoration(
              color: value ? accent : palette.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: value ? Colors.transparent : palette.borderStrong,
              ),
            ),
            child: AnimatedAlign(
              duration: OrgDurations.toggle,
              curve: OrgCurves.spring,
              alignment: value
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: value ? palette.onAccent : palette.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntRangeRow extends StatelessWidget {
  const _IntRangeRow({
    required this.label1,
    required this.label2,
    required this.value1,
    required this.value2,
    required this.accent,
    required this.onChanged1,
    required this.onChanged2,
  });

  final String label1;
  final String label2;
  final int? value1;
  final int? value2;
  final Color accent;
  final ValueChanged<int?> onChanged1;
  final ValueChanged<int?> onChanged2;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SingleIntField(
            label: label1,
            value: value1,
            accent: accent,
            onChanged: onChanged1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SingleIntField(
            label: label2,
            value: value2,
            accent: accent,
            onChanged: onChanged2,
          ),
        ),
      ],
    );
  }
}

class _SingleIntField extends StatefulWidget {
  const _SingleIntField({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final Color accent;
  final ValueChanged<int?> onChanged;

  @override
  State<_SingleIntField> createState() => _SingleIntFieldState();
}

class _SingleIntFieldState extends State<_SingleIntField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value != null ? '${widget.value}' : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: palette.border),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: widget.accent, width: 1.5),
    );

    return TextField(
      controller: _ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) => widget.onChanged(int.tryParse(v)),
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: palette.text, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
        border: border,
        enabledBorder: border,
        focusedBorder: focusBorder,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: palette.bgSecondary,
      ),
    );
  }
}

class _CalendarModeSelector extends StatelessWidget {
  const _CalendarModeSelector({
    required this.value,
    required this.accent,
    required this.accentSoft,
    required this.onChanged,
  });

  final CalendarMode value;
  final Color accent;
  final Color accentSoft;
  final ValueChanged<CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    const options = [
      (CalendarMode.gregorian, 'Gregorian'),
      (CalendarMode.hijri, 'Hijri'),
      (CalendarMode.dual, 'Dual'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Calendar mode',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: options.map((opt) {
            final (mode, label) = opt;
            final active = value == mode;
            return Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: GestureDetector(
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: OrgDurations.toggle,
                    curve: OrgCurves.spring,
                    height: 34,
                    decoration: BoxDecoration(
                      color: active ? accentSoft : palette.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? Colors.transparent : palette.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? accent : palette.textSecondary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PrimaryCalendarSelector extends StatelessWidget {
  const _PrimaryCalendarSelector({
    required this.value,
    required this.accent,
    required this.accentSoft,
    required this.onChanged,
  });

  final CalendarSystem value;
  final Color accent;
  final Color accentSoft;
  final ValueChanged<CalendarSystem> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    const options = [
      (CalendarSystem.gregorian, 'Gregorian first'),
      (CalendarSystem.hijri, 'Hijri first'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Primary calendar',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: options.map((opt) {
            final (sys, label) = opt;
            final active = value == sys;
            return Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: GestureDetector(
                  onTap: () => onChanged(sys),
                  child: AnimatedContainer(
                    duration: OrgDurations.toggle,
                    curve: OrgCurves.spring,
                    height: 34,
                    decoration: BoxDecoration(
                      color: active ? accentSoft : palette.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? Colors.transparent : palette.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? accent : palette.textSecondary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DropdownOptionsEditor extends StatelessWidget {
  const _DropdownOptionsEditor({
    required this.options,
    required this.accent,
    required this.accentSoft,
    required this.newOptionController,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> options;
  final Color accent;
  final Color accentSoft;
  final TextEditingController newOptionController;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (options.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(options.length, (i) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      options[i],
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onRemove(i),
                      child: Icon(Icons.close_rounded, size: 13, color: accent),
                    ),
                  ],
                ),
              );
            }),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _OptionsTextField(
                label: 'New option',
                controller: newOptionController,
                onChanged: (_) {},
                accent: accent,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final val = newOptionController.text.trim();
                if (val.isNotEmpty) {
                  onAdd(val);
                  newOptionController.clear();
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add_rounded, color: accent, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RegexTester extends StatefulWidget {
  const _RegexTester({required this.pattern});

  final String pattern;

  @override
  State<_RegexTester> createState() => _RegexTesterState();
}

class _RegexTesterState extends State<_RegexTester> {
  final TextEditingController _testCtrl = TextEditingController();
  bool? _matches;

  @override
  void dispose() {
    _testCtrl.dispose();
    super.dispose();
  }

  void _test(String value) {
    if (widget.pattern.isEmpty) {
      setState(() => _matches = null);
      return;
    }
    try {
      final re = RegExp(widget.pattern);
      setState(() => _matches = re.hasMatch(value));
    } catch (_) {
      setState(() => _matches = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);

    Color? indicatorColor;
    IconData? indicatorIcon;
    if (_matches == true) {
      indicatorColor = palette.success;
      indicatorIcon = Icons.check_rounded;
    } else if (_matches == false) {
      indicatorColor = palette.danger;
      indicatorIcon = Icons.close_rounded;
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: indicatorColor ?? palette.border,
        width: indicatorColor != null ? 1.5 : 1,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live tester',
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _testCtrl,
          onChanged: _test,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: palette.text,
            fontFamily: 'JetBrainsMono',
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            hintText: 'Test value…',
            hintStyle: TextStyle(color: palette.textTertiary, fontSize: 13),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: palette.bgSecondary,
            suffixIcon: indicatorIcon != null
                ? Icon(indicatorIcon, color: indicatorColor, size: 18)
                : null,
          ),
        ),
      ],
    );
  }
}
