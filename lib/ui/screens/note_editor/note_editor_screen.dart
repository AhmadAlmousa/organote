import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../widgets/form_field/custom_label_field_impl.dart';
import '../../widgets/form_field/date_field_impl.dart';
import '../../widgets/form_field/dropdown_field_impl.dart';
import '../../widgets/form_field/form_field_host.dart';
import '../../widgets/form_field/image_field_impl.dart';
import '../../widgets/form_field/ip_field_impl.dart';
import '../../widgets/form_field/number_field_impl.dart';
import '../../widgets/form_field/password_field_impl.dart';
import '../../widgets/form_field/regex_field_impl.dart';
import '../../widgets/form_field/text_field_impl.dart';
import '../../widgets/form_field/url_field_impl.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/tag_input.dart';

enum _SaveStatus { idle, dirty, saving, saved, error }

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId, this.templateId});

  final String? noteId;
  final String? templateId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  static const Duration _autosaveDelay = Duration(seconds: 2);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final List<_RecordDraft> _records = <_RecordDraft>[];

  String? _currentNoteId;
  Template? _template;
  String? _icon;
  List<String> _tags = const <String>[];
  String _categoryPath = '';
  bool _isPinned = false;
  bool _isFavorite = false;

  _SaveStatus _status = _SaveStatus.idle;
  String? _errorMessage;
  DateTime? _lastSavedAt;
  Timer? _debounce;
  Completer<void>? _flushCompleter;
  bool _seeded = false;
  bool _flushing = false;
  bool _flushQueued = false;
  bool _titleFocused = false;
  Map<String, String> _fieldErrors = const <String, String>{};

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      setState(() => _titleFocused = _titleFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocus.dispose();
    for (final record in _records) {
      record.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final snapshot = ref.watch(librarySnapshotProvider);
    if (!_seeded) {
      _seedFrom(snapshot);
    }
    final categoryHue = _activeHue(snapshot.categories, palette);
    final accent = accentForHue(categoryHue);
    final accentSoft = softForHue(categoryHue, 0.18);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    final horizontalPad = compact ? 12.0 : 18.0;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _flushAndPop();
      },
      child: Scaffold(
        backgroundColor: palette.bg,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _EditorAppBar(
                  status: _status,
                  errorMessage: _errorMessage,
                  lastSavedAt: _lastSavedAt,
                  accent: accent,
                  onBack: _flushAndPop,
                  onDone: _flushAndPop,
                  onTogglePinned: () => _setFlag(pinned: !_isPinned),
                  onToggleFavorite: () => _setFlag(favorite: !_isFavorite),
                  isPinned: _isPinned,
                  isFavorite: _isFavorite,
                  hasTemplate: _template != null,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  4,
                  horizontalPad,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: _TitleRow(
                    accent: accent,
                    accentSoft: accentSoft,
                    icon: _icon,
                    onPickEmoji: (next) {
                      setState(() => _icon = next);
                      _touch();
                    },
                    titleController: _titleController,
                    titleFocusNode: _titleFocus,
                    titleFocused: _titleFocused,
                    onTitleChanged: _touch,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  4,
                  horizontalPad,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: _TemplateRow(
                    template: _template,
                    accent: accent,
                    onChange: () => _showTemplatePicker(snapshot.templates),
                    onClear: _template == null
                        ? null
                        : () {
                            setState(() => _template = null);
                            _resetRecordsForTemplate(null);
                            _touch();
                          },
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  4,
                  horizontalPad,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: _SectionLabel(label: 'Category'),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  0,
                  horizontalPad,
                  16,
                ),
                sliver: SliverToBoxAdapter(
                  child: CategorySelector(
                    categories: snapshot.categories,
                    selectedPath: _categoryPath,
                    onSelect: (next) {
                      setState(() => _categoryPath = next);
                      _touch();
                    },
                    onCreate: _createCategory,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  4,
                  horizontalPad,
                  6,
                ),
                sliver: SliverToBoxAdapter(child: _SectionLabel(label: 'Tags')),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  0,
                  horizontalPad,
                  18,
                ),
                sliver: SliverToBoxAdapter(
                  child: TagInput(
                    tags: _tags,
                    suggestions: snapshot.tags,
                    accent: accent,
                    onChanged: (next) {
                      setState(() => _tags = next);
                      _touch();
                    },
                  ),
                ),
              ),
              if (_records.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    4,
                    horizontalPad,
                    8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          'Records',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_records.length}',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            color: palette.textTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    0,
                    horizontalPad,
                    8,
                  ),
                  sliver: SliverList.separated(
                    itemCount: _records.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final record = _records[index];
                      return _RecordEditorCard(
                        index: index,
                        record: record,
                        template: _template,
                        accent: accent,
                        accentSoft: accentSoft,
                        showRemove: _records.length > 1,
                        fieldErrors: _fieldErrors,
                        onRemove: () => _removeRecord(index),
                        onTouched: _touch,
                        ensureNoteIdForAsset: _ensureNoteIdForAsset,
                      );
                    },
                  ),
                ),
              ],
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  6,
                  horizontalPad,
                  10,
                ),
                sliver: SliverToBoxAdapter(
                  child: _AddRecordButton(
                    accent: accent,
                    accentSoft: accentSoft,
                    label: _template == null
                        ? 'Add freeform record'
                        : 'Add ${_template!.name.toLowerCase()} record',
                    onTap: _addRecord,
                  ),
                ),
              ),
              if (_template == null)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    8,
                    horizontalPad,
                    10,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _BodyEditor(
                      controller: _bodyController,
                      accent: accent,
                      onChanged: _touch,
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPad,
                  16,
                  horizontalPad,
                  compact ? 28 : 48,
                ),
                sliver: SliverToBoxAdapter(
                  child: _FooterActions(
                    accent: accent,
                    onSave: _flushAndPop,
                    saving:
                        _status == _SaveStatus.saving ||
                        _status == _SaveStatus.dirty,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seedFrom(LibrarySnapshot snapshot) {
    _seeded = true;
    final existingId = widget.noteId;
    if (existingId != null) {
      final note = _findNote(snapshot.notes, existingId);
      if (note != null) {
        _currentNoteId = note.id;
        _template = _findTemplate(snapshot.templates, note.templateId);
        _icon = note.icon;
        _tags = List<String>.from(note.tags);
        _categoryPath = note.categoryPath;
        _isPinned = note.isPinned;
        _isFavorite = note.isFavorite;
        _titleController.text = note.title;
        _bodyController.text = note.body;
        _records
          ..clear()
          ..addAll(
            note.records.map(
              (record) => _RecordDraft.fromRecord(record, _template),
            ),
          );
        _status = _SaveStatus.saved;
        _lastSavedAt = note.updatedAt ?? DateTime.now().toUtc();
        if (_records.isEmpty) {
          _records.add(_RecordDraft.empty(_template, index: 0));
        }
        return;
      }
    }
    final templateId = widget.templateId;
    if (templateId != null) {
      _template = _findTemplate(snapshot.templates, templateId);
    } else if (snapshot.templates.isNotEmpty) {
      _template = snapshot.templates.first;
    }
    _records
      ..clear()
      ..add(_RecordDraft.empty(_template, index: 0));
  }

  void _addRecord() {
    setState(() {
      _records.add(_RecordDraft.empty(_template, index: _records.length));
    });
    _touch();
  }

  void _removeRecord(int index) {
    if (_records.length <= 1) return;
    setState(() {
      _records[index].dispose();
      _records.removeAt(index);
      for (var i = 0; i < _records.length; i += 1) {
        _records[i].defaultLabel = _RecordDraft.labelFor(_template, i);
      }
    });
    _touch();
  }

  void _resetRecordsForTemplate(Template? template) {
    for (final record in _records) {
      record.dispose();
    }
    _records
      ..clear()
      ..add(_RecordDraft.empty(template, index: 0));
  }

  void _setFlag({bool? pinned, bool? favorite}) {
    setState(() {
      if (pinned != null) _isPinned = pinned;
      if (favorite != null) _isFavorite = favorite;
    });
    _touch();
  }

  void _touch() {
    if (_flushing || _status == _SaveStatus.saving) {
      _flushQueued = true;
    }
    if (_status != _SaveStatus.saving) {
      setState(() {
        _status = _SaveStatus.dirty;
        _errorMessage = null;
      });
    }
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, _flush);
  }

  Future<void> _flushAndPop() async {
    _debounce?.cancel();
    if (_status == _SaveStatus.dirty || _status == _SaveStatus.saving) {
      await _flush();
    }
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _flush() async {
    if (_flushing) {
      _flushQueued = true;
      await _flushCompleter?.future;
      return;
    }
    final completer = Completer<void>();
    _flushCompleter = completer;
    _flushing = true;
    try {
      do {
        _flushQueued = false;
        _debounce?.cancel();
        final repo = ref.read(noteRepositoryProvider);
        final input = _buildInput();
        if (!_hasContent(input)) {
          return;
        }
        setState(() => _status = _SaveStatus.saving);
        try {
          final saved = await repo.saveStructuredNote(input);
          if (!mounted) {
            return;
          }
          _debounce?.cancel();
          setState(() {
            _currentNoteId = saved.id;
            _status = _flushQueued ? _SaveStatus.dirty : _SaveStatus.saved;
            _lastSavedAt = saved.updatedAt ?? DateTime.now().toUtc();
            _errorMessage = null;
            _fieldErrors = const <String, String>{};
          });
        } catch (err) {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = _SaveStatus.error;
            _errorMessage = err.toString();
          });
        }
      } while (_flushQueued);
    } finally {
      _flushing = false;
      _flushCompleter = null;
      completer.complete();
    }
  }

  Future<String?> _ensureNoteIdForAsset() async {
    _debounce?.cancel();
    while (_flushing || _status == _SaveStatus.saving) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (_currentNoteId == null ||
        _status == _SaveStatus.dirty ||
        _status == _SaveStatus.error) {
      await _flush();
    }
    while (_flushing || _status == _SaveStatus.saving) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    return _currentNoteId;
  }

  bool _hasContent(NoteInput input) {
    if (input.title.trim().isNotEmpty) return true;
    if (input.body.trim().isNotEmpty) return true;
    for (final record in input.records) {
      if (record.values.values.any((v) => v.trim().isNotEmpty)) return true;
    }
    return false;
  }

  NoteInput _buildInput() {
    final records = <NoteRecord>[];
    for (var i = 0; i < _records.length; i += 1) {
      final draft = _records[i];
      records.add(draft.toRecord(_template, index: i));
    }
    return NoteInput(
      id: _currentNoteId,
      title: _titleController.text.trim(),
      templateId: _template?.id,
      templateName: _template?.name,
      templateVersion: _template?.version ?? 0,
      icon: _icon,
      tags: _tags,
      categoryPath: _categoryPath,
      records: records,
      body: _template == null ? _bodyController.text : '',
      isPinned: _isPinned,
      isFavorite: _isFavorite,
    );
  }

  Future<void> _createCategory(String name, String hex) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final repo = ref.read(categoryRepositoryProvider);
    final path = _slug(name);
    try {
      await repo.saveCategory(
        Category(path: path, name: name, colorHex: hex, noteCount: 0),
      );
      setState(() => _categoryPath = path);
      _touch();
    } catch (err) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not create: $err')),
      );
    }
  }

  Future<void> _showTemplatePicker(List<Template> templates) async {
    final palette = OrgPaletteScope.of(context);
    final selected = await showModalBottomSheet<Template?>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              const SizedBox(height: 16),
              Text(
                'Use a template',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (templates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No templates yet — build one from the Templates tab.',
                    style: TextStyle(color: palette.textSecondary),
                  ),
                )
              else
                for (final template in templates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        template.icon ?? '✦',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    title: Text(
                      template.name,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${template.fields.length} field${template.fields.length == 1 ? '' : 's'}',
                      style: TextStyle(color: palette.textTertiary),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(template),
                  ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: palette.bgSecondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.notes_rounded,
                    color: palette.textSecondary,
                    size: 18,
                  ),
                ),
                title: Text(
                  'No template',
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Freeform body, no schema',
                  style: TextStyle(color: palette.textTertiary),
                ),
                onTap: () => Navigator.of(sheetContext).pop(null),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (selected?.id == _template?.id) return;
    setState(() {
      _template = selected;
      _resetRecordsForTemplate(selected);
    });
    _touch();
  }

  double _activeHue(List<Category> categories, OrgPalette palette) {
    if (_categoryPath.isEmpty) return palette.accentHue;
    for (final c in categories) {
      if (c.path == _categoryPath) {
        return hueOfCategory(c, fallbackHue: palette.accentHue);
      }
    }
    return palette.accentHue;
  }

  String _slug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_\-/]'), '');
  }

  Note? _findNote(List<Note> notes, String id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Template? _findTemplate(List<Template> templates, String? id) {
    if (id == null) return null;
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class _RecordDraft {
  _RecordDraft({
    required this.labelController,
    required this.fieldControllers,
    this.id,
    Map<String, String> extraValues = const <String, String>{},
    this.defaultLabel = 'Record 1',
  }) : extraFieldControllers = {
         for (final entry in extraValues.entries)
           entry.key: TextEditingController(text: entry.value),
       };

  factory _RecordDraft.empty(Template? template, {required int index}) {
    final initialLabel = template == null || template.fields.isEmpty
        ? labelFor(template, index)
        : '';
    final labelCtl = TextEditingController(text: initialLabel);
    final fieldCtls = <String, TextEditingController>{};
    if (template != null) {
      for (final field in template.fields) {
        fieldCtls[field.id] = TextEditingController();
      }
    }
    return _RecordDraft(
      labelController: labelCtl,
      fieldControllers: fieldCtls,
      defaultLabel: initialLabel,
    );
  }

  factory _RecordDraft.fromRecord(NoteRecord record, Template? template) {
    final labelCtl = TextEditingController(text: record.label);
    final fieldCtls = <String, TextEditingController>{};
    final extras = <String, String>{};
    if (template != null) {
      for (final field in template.fields) {
        final value = _fieldValue(record.values, field);
        fieldCtls[field.id] = TextEditingController(text: value);
      }
      final templateKeys = <String>{
        for (final field in template.fields) ...[
          field.label,
          field.id,
          _normalizedFieldKey(field.label),
          _normalizedFieldKey(field.id),
        ],
      };
      for (final entry in record.values.entries) {
        if (!templateKeys.contains(entry.key) &&
            !templateKeys.contains(_normalizedFieldKey(entry.key))) {
          extras[entry.key] = entry.value;
        }
      }
    } else {
      for (final entry in record.values.entries) {
        fieldCtls[entry.key] = TextEditingController(text: entry.value);
      }
    }
    return _RecordDraft(
      id: record.id,
      labelController: labelCtl,
      fieldControllers: fieldCtls,
      extraValues: extras,
      defaultLabel: record.label,
    );
  }

  static String labelFor(Template? template, int index) {
    final base = template?.name ?? 'Record';
    return '$base ${index + 1}';
  }

  final String? id;
  final TextEditingController labelController;
  final Map<String, TextEditingController> fieldControllers;
  final Map<String, TextEditingController> extraFieldControllers;
  String defaultLabel;

  NoteRecord toRecord(Template? template, {required int index}) {
    final values = <String, String>{};
    if (template != null) {
      for (final field in template.fields) {
        final v = fieldControllers[field.id]?.text ?? '';
        if (v.trim().isNotEmpty) {
          values[field.label] = v;
        }
      }
      for (final entry in extraFieldControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          values[entry.key] = entry.value.text;
        }
      }
    } else {
      for (final entry in fieldControllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          values[entry.key] = entry.value.text;
        }
      }
    }
    final label =
        _derivedTemplateLabel(template, values) ??
        (labelController.text.trim().isEmpty
            ? labelFor(template, index)
            : labelController.text.trim());
    return NoteRecord(id: id, label: label, values: values);
  }

  String? previewLabel(Template? template) {
    if (template == null || template.fields.isEmpty) {
      return null;
    }
    final values = <String, String>{};
    for (final field in template.fields) {
      final value = fieldControllers[field.id]?.text ?? '';
      if (value.trim().isNotEmpty) {
        values[field.label] = value;
      }
    }
    return _derivedTemplateLabel(template, values);
  }

  void dispose() {
    labelController.dispose();
    for (final c in fieldControllers.values) {
      c.dispose();
    }
    for (final c in extraFieldControllers.values) {
      c.dispose();
    }
  }
}

String _fieldValue(Map<String, String> values, TemplateField field) {
  return values[field.label] ??
      values[field.id] ??
      values[_normalizedFieldKey(field.label)] ??
      values[_normalizedFieldKey(field.id)] ??
      '';
}

String? _derivedTemplateLabel(Template? template, Map<String, String> values) {
  if (template == null || template.fields.isEmpty) {
    return null;
  }
  final first = template.fields.first;
  final value = _fieldValue(values, first).trim();
  if (value.isEmpty || value.contains('\n') || value.contains('\r')) {
    return null;
  }
  return '${first.label}: $value';
}

String _normalizedFieldKey(String value) {
  return value
      .replaceAll('*', '')
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _EditorAppBar extends StatelessWidget {
  const _EditorAppBar({
    required this.status,
    required this.errorMessage,
    required this.lastSavedAt,
    required this.accent,
    required this.onBack,
    required this.onDone,
    required this.onTogglePinned,
    required this.onToggleFavorite,
    required this.isPinned,
    required this.isFavorite,
    required this.hasTemplate,
  });

  final _SaveStatus status;
  final String? errorMessage;
  final DateTime? lastSavedAt;
  final Color accent;
  final VoidCallback onBack;
  final VoidCallback onDone;
  final VoidCallback onTogglePinned;
  final VoidCallback onToggleFavorite;
  final bool isPinned;
  final bool isFavorite;
  final bool hasTemplate;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 10, compact ? 10 : 14, 6),
      child: Row(
        children: [
          OrgIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
            tooltip: 'Back',
            size: 38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatusBadge(status: status, accent: accent),
          ),
          const SizedBox(width: 8),
          OrgIconButton(
            icon: isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            onPressed: onTogglePinned,
            tooltip: isPinned ? 'Unpin' : 'Pin',
            size: 38,
            foreground: isPinned ? accent : palette.textSecondary,
          ),
          const SizedBox(width: 6),
          OrgIconButton(
            icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            onPressed: onToggleFavorite,
            tooltip: isFavorite ? 'Unfavorite' : 'Favorite',
            size: 38,
            foreground: isFavorite ? palette.accent : palette.textSecondary,
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: palette.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.accent});

  final _SaveStatus status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    late final IconData icon;
    late final String label;
    late final Color color;
    switch (status) {
      case _SaveStatus.idle:
        icon = Icons.edit_note_rounded;
        label = 'Ready';
        color = palette.textSecondary;
      case _SaveStatus.dirty:
        icon = Icons.timelapse_rounded;
        label = 'Autosaving…';
        color = accent;
      case _SaveStatus.saving:
        icon = Icons.cloud_upload_outlined;
        label = 'Saving';
        color = accent;
      case _SaveStatus.saved:
        icon = Icons.check_rounded;
        label = 'Saved';
        color = palette.success;
      case _SaveStatus.error:
        icon = Icons.error_outline_rounded;
        label = 'Save failed';
        color = palette.danger;
    }
    return AnimatedSwitcher(
      duration: OrgDurations.toggle,
      switchInCurve: OrgCurves.spring,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey(label),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.accent,
    required this.accentSoft,
    required this.icon,
    required this.onPickEmoji,
    required this.titleController,
    required this.titleFocusNode,
    required this.titleFocused,
    required this.onTitleChanged,
  });

  final Color accent;
  final Color accentSoft;
  final String? icon;
  final ValueChanged<String?> onPickEmoji;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final bool titleFocused;
  final VoidCallback onTitleChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EmojiPickerButton(value: icon, onPicked: onPickEmoji, size: 64),
        const SizedBox(width: 10),
        Expanded(
          child: AnimatedContainer(
            duration: OrgDurations.toggle,
            curve: OrgCurves.spring,
            padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 14, 4),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: titleFocused ? accent : palette.border,
                width: titleFocused ? 1.4 : 1.0,
              ),
              boxShadow: titleFocused
                  ? [
                      BoxShadow(
                        color: accent.withAlpha(48),
                        blurRadius: 22,
                        spreadRadius: -8,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              key: const Key('note-title-field'),
              controller: titleController,
              focusNode: titleFocusNode,
              cursorColor: accent,
              onChanged: (_) => onTitleChanged(),
              textInputAction: TextInputAction.next,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.02,
                height: 1.15,
              ),
              decoration: InputDecoration(
                hintText: 'Untitled note',
                hintStyle: TextStyle(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: -0.02,
                ),
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.accent,
    required this.onChange,
    required this.onClear,
  });

  final Template? template;
  final Color accent;
  final VoidCallback onChange;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              template?.icon ?? '✦',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEMPLATE',
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.06,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  template?.name ?? 'No template — freeform body',
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Detach template',
              onPressed: onClear,
              icon: Icon(
                Icons.link_off_rounded,
                color: palette.textSecondary,
                size: 18,
              ),
              splashRadius: 18,
            ),
        ],
      ),
    );
  }
}

class _RecordEditorCard extends StatefulWidget {
  const _RecordEditorCard({
    required this.index,
    required this.record,
    required this.template,
    required this.accent,
    required this.accentSoft,
    required this.showRemove,
    required this.fieldErrors,
    required this.onRemove,
    required this.onTouched,
    required this.ensureNoteIdForAsset,
  });

  final int index;
  final _RecordDraft record;
  final Template? template;
  final Color accent;
  final Color accentSoft;
  final bool showRemove;
  final Map<String, String> fieldErrors;
  final VoidCallback onRemove;
  final VoidCallback onTouched;
  final Future<String?> Function() ensureNoteIdForAsset;

  @override
  State<_RecordEditorCard> createState() => _RecordEditorCardState();
}

class _RecordEditorCardState extends State<_RecordEditorCard> {
  bool _expanded = true;
  bool _labelFocused = false;
  late final FocusNode _labelFocus = FocusNode()
    ..addListener(() => setState(() => _labelFocused = _labelFocus.hasFocus));

  @override
  void dispose() {
    _labelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final usesTemplateFields =
        widget.template != null && widget.template!.fields.isNotEmpty;
    final previewLabel = widget.record.previewLabel(widget.template);
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
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${widget.index + 1}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      color: widget.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: usesTemplateFields
                      ? Text(
                          previewLabel ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        )
                      : TextField(
                          controller: widget.record.labelController,
                          focusNode: _labelFocus,
                          cursorColor: widget.accent,
                          onChanged: (_) => widget.onTouched(),
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.01,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.record.defaultLabel,
                            hintStyle: TextStyle(
                              color: _labelFocused
                                  ? palette.textSecondary
                                  : palette.textTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                            isCollapsed: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),
                          ),
                        ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: OrgDurations.toggle,
                    curve: OrgCurves.spring,
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                  ),
                  splashRadius: 18,
                ),
                if (widget.showRemove)
                  IconButton(
                    tooltip: 'Remove record',
                    onPressed: widget.onRemove,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: palette.textSecondary,
                      size: 18,
                    ),
                    splashRadius: 18,
                  ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: OrgDurations.toggle,
            sizeCurve: OrgCurves.spring,
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
              child: _RecordFields(
                record: widget.record,
                template: widget.template,
                accent: widget.accent,
                fieldErrors: widget.fieldErrors,
                onTouched: widget.onTouched,
                ensureNoteIdForAsset: widget.ensureNoteIdForAsset,
              ),
            ),
            secondChild: const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

class _RecordFields extends ConsumerWidget {
  const _RecordFields({
    required this.record,
    required this.template,
    required this.accent,
    required this.fieldErrors,
    required this.onTouched,
    required this.ensureNoteIdForAsset,
  });

  final _RecordDraft record;
  final Template? template;
  final Color accent;
  final Map<String, String> fieldErrors;
  final VoidCallback onTouched;
  final Future<String?> Function() ensureNoteIdForAsset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = this.template;
    if (template == null || template.fields.isEmpty) {
      return _FreeformFieldList(
        record: record,
        accent: accent,
        onTouched: onTouched,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < template.fields.length; i += 1) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildField(ref, template.fields[i]),
        ],
        if (record.extraFieldControllers.isNotEmpty) ...[
          const SizedBox(height: 14),
          _DetachedFieldList(
            record: record,
            accent: accent,
            onTouched: onTouched,
          ),
        ],
      ],
    );
  }

  Widget _buildField(WidgetRef ref, TemplateField field) {
    final controller = record.fieldControllers[field.id]!;
    final error = fieldErrors['${record.id ?? ''}::${field.id}'];
    switch (field.type) {
      case TemplateFieldType.text:
        return TextFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.number:
        return NumberFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.dropdown:
        return DropdownFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.password:
        return PasswordFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.url:
        return UrlFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.ip:
        return IpFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.boolean:
        return _BooleanField(
          field: field,
          controller: controller,
          accent: accent,
          onChanged: onTouched,
        );
      case TemplateFieldType.date:
        return DateFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.image:
        return ImageFieldImpl(
          field: field,
          controller: controller,
          assetRepository: ref.read(assetRepositoryProvider),
          ensureNoteId: ensureNoteIdForAsset,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.customLabel:
        return CustomLabelFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          error: error,
          accent: accent,
        );
      case TemplateFieldType.regex:
        return RegexFieldImpl(
          field: field,
          controller: controller,
          onChanged: onTouched,
          accent: accent,
          error: error,
        );
    }
  }
}

class _DetachedFieldList extends StatefulWidget {
  const _DetachedFieldList({
    required this.record,
    required this.accent,
    required this.onTouched,
  });

  final _RecordDraft record;
  final Color accent;
  final VoidCallback onTouched;

  @override
  State<_DetachedFieldList> createState() => _DetachedFieldListState();
}

class _DetachedFieldListState extends State<_DetachedFieldList> {
  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final entries = widget.record.extraFieldControllers.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: palette.warning, size: 15),
            const SizedBox(width: 6),
            Text(
              'Not in template',
              style: TextStyle(
                color: palette.warning,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${entries.length}',
              style: TextStyle(
                color: palette.textTertiary,
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < entries.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 12),
          FormFieldHost(
            label: entries[index].key,
            accent: palette.warning,
            focused: true,
            trailing: IconButton(
              tooltip: 'Remove preserved field',
              onPressed: () => _remove(entries[index].key),
              icon: Icon(
                Icons.close_rounded,
                color: palette.textSecondary,
                size: 16,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            ),
            hint: 'Preserved from an older template version',
            child: TextField(
              key: Key('detached-field-${entries[index].key}'),
              controller: entries[index].value,
              cursorColor: palette.warning,
              onChanged: (_) => widget.onTouched(),
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _remove(String key) {
    final controller = widget.record.extraFieldControllers.remove(key);
    controller?.dispose();
    widget.onTouched();
    setState(() {});
  }
}

class _FreeformFieldList extends StatelessWidget {
  const _FreeformFieldList({
    required this.record,
    required this.accent,
    required this.onTouched,
  });

  final _RecordDraft record;
  final Color accent;
  final VoidCallback onTouched;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    if (record.fieldControllers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              color: palette.textTertiary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Attach a template to add structured fields.',
                style: TextStyle(
                  color: palette.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in record.fieldControllers.entries) ...[
          FormFieldHost(
            label: entry.key,
            accent: accent,
            child: TextField(
              controller: entry.value,
              cursorColor: accent,
              onChanged: (_) => onTouched(),
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BooleanField extends StatelessWidget {
  const _BooleanField({
    required this.field,
    required this.controller,
    required this.accent,
    required this.onChanged,
  });

  final TemplateField field;
  final TextEditingController controller;
  final Color accent;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final isTrue = _isTrue(controller.text);
    return FormFieldHost(
      label: field.label,
      required: field.isRequired,
      accent: accent,
      hint: field.hint,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _BoolChip(
              label: 'True',
              active: isTrue,
              accent: accent,
              palette: palette,
              onTap: () {
                controller.text = 'true';
                onChanged();
              },
            ),
            const SizedBox(width: 8),
            _BoolChip(
              label: 'False',
              active: controller.text.trim().isNotEmpty && !isTrue,
              accent: palette.textSecondary,
              palette: palette,
              onTap: () {
                controller.text = 'false';
                onChanged();
              },
            ),
            const Spacer(),
            if (controller.text.trim().isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.text = '';
                  onChanged();
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isTrue(String raw) {
    final v = raw.trim().toLowerCase();
    return v == 'true' || v == 'yes' || v == '1';
  }
}

class _BoolChip extends StatelessWidget {
  const _BoolChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final OrgPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: OrgDurations.toggle,
        curve: OrgCurves.spring,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? accent : palette.bgSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? Colors.transparent : palette.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? palette.onAccent : palette.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _AddRecordButton extends StatefulWidget {
  const _AddRecordButton({
    required this.accent,
    required this.accentSoft,
    required this.label,
    required this.onTap,
  });

  final Color accent;
  final Color accentSoft;
  final String label;
  final VoidCallback onTap;

  @override
  State<_AddRecordButton> createState() => _AddRecordButtonState();
}

class _AddRecordButtonState extends State<_AddRecordButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: OrgDurations.toggle,
          curve: OrgCurves.spring,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: _hover ? widget.accentSoft : palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover ? widget.accent : palette.borderStrong,
              width: 1.2,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: widget.accent, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: 0.02,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BodyEditor extends StatefulWidget {
  const _BodyEditor({
    required this.controller,
    required this.accent,
    required this.onChanged,
  });

  final TextEditingController controller;
  final Color accent;
  final VoidCallback onChanged;

  @override
  State<_BodyEditor> createState() => _BodyEditorState();
}

class _BodyEditorState extends State<_BodyEditor> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormFieldHost(
      label: 'Notes',
      hint: 'Markdown is fine — gets stored after the data block',
      focused: _focused,
      accent: widget.accent,
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        cursorColor: widget.accent,
        maxLines: null,
        minLines: 4,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        onChanged: (_) => widget.onChanged(),
        style: const TextStyle(height: 1.45),
        decoration: const InputDecoration(
          hintText: 'Notes, thoughts, links…',
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 0, 2, 0),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.06,
          color: palette.textTertiary,
        ),
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.accent,
    required this.onSave,
    required this.saving,
  });

  final Color accent;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textSecondary,
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
            onPressed: onSave,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: palette.onAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(saving ? 'Save & close' : 'Done'),
          ),
        ),
      ],
    );
  }
}
