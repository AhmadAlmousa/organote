import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/util/image_field_values.dart';
import '../../state/app_providers.dart';
import '../../state/library_provider.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../util/category_color.dart';
import '../../util/relative_time.dart';
import '../../util/share_intent.dart';
import '../../util/share_text_builder.dart';
import '../../app/overlay_route.dart';
import '../../widgets/copy_row.dart';
import '../../widgets/org_empty_state.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_toast.dart';
import '../../widgets/record_card.dart';
import '../note_editor/note_editor_screen.dart';
import '../note_editor/raw_source_editor.dart';
import '../template_builder/template_builder_screen.dart';

class NoteViewerScreen extends ConsumerWidget {
  const NoteViewerScreen({super.key, required this.noteId});

  final String noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = OrgPaletteScope.of(context);
    final library = ref.watch(librarySnapshotProvider);
    final note = _findNote(library.notes, noteId);

    if (note == null) {
      return Scaffold(
        backgroundColor: palette.bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: palette.text),
        ),
        body: const OrgEmptyState(
          emoji: '∅',
          message: 'This note is gone',
          subtitle: 'It may have been deleted or moved. Pull down to refresh.',
        ),
      );
    }

    final template = _findTemplate(library.templates, note.templateId);
    final category = _findCategory(library.categories, note.categoryPath);
    final hue = category != null
        ? hueOfCategory(category, fallbackHue: palette.accentHue)
        : palette.accentHue;
    final accent = accentForHue(hue);
    final accentSoft = softForHue(hue, 0.22);
    final accentDeep = deepForHue(hue);

    return _ViewerBody(
      note: note,
      template: template,
      category: category,
      accent: accent,
      accentSoft: accentSoft,
      accentDeep: accentDeep,
      hueColor: accent,
    );
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

  Category? _findCategory(List<Category> categories, String path) {
    if (path.isEmpty) return null;
    for (final c in categories) {
      if (c.path == path) return c;
    }
    return null;
  }
}

class _ViewerBody extends ConsumerStatefulWidget {
  const _ViewerBody({
    required this.note,
    required this.template,
    required this.category,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.hueColor,
  });

  final Note note;
  final Template? template;
  final Category? category;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final Color hueColor;

  @override
  ConsumerState<_ViewerBody> createState() => _ViewerBodyState();
}

class _ViewerBodyState extends ConsumerState<_ViewerBody> {
  bool _deleting = false;

  Future<void> _share(BuildContext context) async {
    final text = buildShareText(widget.note, template: widget.template);
    final ok = await shareOrCopy(text: text, subject: widget.note.title);
    if (!context.mounted) return;
    showOrgToast(
      context,
      message: ok ? 'Shared as plain text' : 'Copied to clipboard',
      icon: Icons.check_rounded,
      background: widget.accent,
    );
  }

  Future<void> _delete(BuildContext context) async {
    if (_deleting) return;
    final confirmed = await _confirmDelete(context);
    if (!confirmed || !context.mounted) return;
    setState(() => _deleting = true);
    final navigator = Navigator.of(context);
    final messengerContext = navigator.context;
    final id = widget.note.id;
    if (navigator.canPop()) navigator.pop();
    unawaited(_softDelete(messengerContext, id));
  }

  Future<void> _softDelete(BuildContext messengerContext, String id) async {
    try {
      await ref.read(noteRepositoryProvider).softDeleteNote(id);
      if (!messengerContext.mounted) return;
      showOrgToast(
        messengerContext,
        message: 'Moved to trash',
        icon: Icons.delete_outline_rounded,
        background: widget.accent,
      );
    } catch (_) {
      if (!messengerContext.mounted) return;
      final palette = OrgPaletteScope.of(messengerContext);
      showOrgToast(
        messengerContext,
        message: 'Delete failed — try again',
        icon: Icons.error_outline_rounded,
        background: palette.danger,
        foreground: palette.onAccent,
      );
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final palette = OrgPaletteScope.of(context);
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
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
              const SizedBox(height: 16),
              Text(
                'Move to trash?',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  color: palette.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can restore "${widget.note.title.isEmpty ? 'this note' : widget.note.title}" from Settings → Trash within 7 days.',
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        side: BorderSide(color: palette.borderStrong),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Keep'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.danger,
                        foregroundColor: palette.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Move to trash'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  void _toastSoon(BuildContext context, String message) {
    showOrgToast(
      context,
      message: message,
      icon: Icons.schedule_rounded,
      background: widget.accent,
    );
  }

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(
        builder: (_) => NoteEditorScreen(noteId: widget.note.id),
      ),
    );
  }

  void _openRawSource(BuildContext context) {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(
        builder: (_) => RawSourceEditorScreen(
          noteId: widget.note.id,
          noteTitle: widget.note.title,
        ),
      ),
    );
  }

  void _openTemplateBuilder(BuildContext context) {
    final template = widget.template;
    if (template == null) {
      _toastSoon(context, 'This note has no template');
      return;
    }
    Navigator.of(context).push(
      OrgOverlayRoute<void>(
        builder: (_) => TemplateBuilderScreen(templateId: template.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    final horizontalPad = compact ? 12.0 : 18.0;
    final layout = widget.template?.layout ?? TemplateLayout.cards;

    final hasRecords = widget.note.records.isNotEmpty;
    final hasBody = widget.note.body.trim().isNotEmpty;
    final fieldsList =
        (layout == TemplateLayout.cards && hasRecords)
            ? _buildRecordWidgets()
            : const <Widget>[];

    return Scaffold(
      backgroundColor: palette.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _ViewerHeader(
              note: widget.note,
              template: widget.template,
              category: widget.category,
              accent: widget.accent,
              accentSoft: widget.accentSoft,
              accentDeep: widget.accentDeep,
              compact: compact,
              onBack: () => Navigator.of(context).maybePop(),
              onShare: () => _share(context),
              onEdit: () => _openEditor(context),
              onMore: () => _showMoreMenu(context),
            ),
          ),
          if (!hasRecords && !hasBody)
            SliverFillRemaining(
              hasScrollBody: false,
              child: OrgEmptyState(
                emoji: widget.note.icon ?? '✦',
                message: 'Nothing recorded yet',
                subtitle: widget.template == null
                    ? 'This note has no template and no body.'
                    : 'Open in editor to fill ${widget.template!.fields.length} field${widget.template!.fields.length == 1 ? '' : 's'}.',
              ),
            )
          else ...[
            if (hasRecords)
              _recordsSliver(layout, fieldsList, horizontalPad, compact),
            if (hasBody)
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  horizontalPad,
                  18,
                  horizontalPad,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _BodyBlock(
                    body: widget.note.body.trim(),
                    palette: palette,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: compact ? 28 : 36)),
          ],
        ],
      ),
    );
  }

  Widget _recordsSliver(
    TemplateLayout layout,
    List<Widget> fieldsList,
    double horizontalPad,
    bool compact,
  ) {
    final padding = EdgeInsetsDirectional.fromSTEB(
      horizontalPad,
      compact ? 10.0 : 14.0,
      horizontalPad,
      0,
    );
    return switch (layout) {
      TemplateLayout.grid => SliverPadding(
        padding: padding,
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          crossAxisSpacing: compact ? 10.0 : 12.0,
          mainAxisSpacing: compact ? 10.0 : 12.0,
          childAspectRatio: 0.82,
          children: [
            for (var i = 0; i < widget.note.records.length; i++)
              _GridRecordTile(
                index: i,
                record: widget.note.records[i],
                template: widget.template,
                accent: widget.accent,
                accentSoft: widget.accentSoft,
              ),
          ],
        ),
      ),
      TemplateLayout.table => SliverPadding(
        padding: padding,
        sliver: SliverToBoxAdapter(
          child: _TableRecordsList(
            records: widget.note.records,
            template: widget.template,
            accent: widget.accent,
            accentSoft: widget.accentSoft,
          ),
        ),
      ),
      _ => SliverPadding(
        padding: padding,
        sliver: SliverList.separated(
          itemCount: fieldsList.length,
          separatorBuilder: (_, _) => SizedBox(height: compact ? 10 : 14),
          itemBuilder: (_, index) => fieldsList[index],
        ),
      ),
    };
  }

  List<Widget> _buildRecordWidgets() {
    final imageRefs = _collectImageRefs();
    AssetRepository? assetRepository;
    AssetRepository requireAssetRepository() {
      final existing = assetRepository;
      if (existing != null) return existing;
      final repo = ref.read(assetRepositoryProvider);
      assetRepository = repo;
      return repo;
    }

    final widgets = <Widget>[];
    var imageCursor = 0;
    for (var i = 0; i < widget.note.records.length; i += 1) {
      final record = widget.note.records[i];
      final orderedKeys = <String>[];
      final templateFieldByKey = <String, TemplateField>{};
      if (widget.template != null) {
        for (final field in widget.template!.fields) {
          final key = _fieldValueKey(record.values, field);
          if (key != null) {
            orderedKeys.add(key);
            templateFieldByKey[key] = field;
          }
        }
      }
      for (final key in record.values.keys) {
        if (!orderedKeys.contains(key)) orderedKeys.add(key);
      }
      final fields = <Widget>[];
      for (var k = 0; k < orderedKeys.length; k += 1) {
        final key = orderedKeys[k];
        final value = record.values[key] ?? '';
        final field = templateFieldByKey[key];
        final last = k == orderedKeys.length - 1;
        final paths = _imagePathsFor(field, key, value);
        if (paths.isNotEmpty) {
          final firstIndex = imageCursor;
          imageCursor += paths.length;
          fields.add(
            _ImageFieldRow(
              label: field?.label ?? key,
              paths: paths,
              accent: widget.accent,
              accentSoft: widget.accentSoft,
              assetRepository: requireAssetRepository(),
              imageRefs: imageRefs,
              imageIndex: firstIndex,
            ),
          );
        } else {
          fields.add(_fieldRow(key, value, field, last: last));
        }
      }
      widgets.add(
        RecordCard(
          index: i,
          record: record,
          accent: widget.accent,
          accentSoft: widget.accentSoft,
          fields: fields,
          onCopyAll: () => _onCopyAll(record),
        ),
      );
    }
    return widgets;
  }

  List<_ImageRef> _collectImageRefs() {
    final refs = <_ImageRef>[];
    for (final record in widget.note.records) {
      final orderedKeys = <String>[];
      final templateFieldByKey = <String, TemplateField>{};
      if (widget.template != null) {
        for (final field in widget.template!.fields) {
          final key = _fieldValueKey(record.values, field);
          if (key != null) {
            orderedKeys.add(key);
            templateFieldByKey[key] = field;
          }
        }
      }
      for (final key in record.values.keys) {
        if (!orderedKeys.contains(key)) orderedKeys.add(key);
      }
      for (final key in orderedKeys) {
        final value = record.values[key]?.trim() ?? '';
        if (value.isEmpty) continue;
        final field = templateFieldByKey[key];
        final paths = _imagePathsFor(field, key, value);
        if (paths.isEmpty) continue;
        for (var index = 0; index < paths.length; index += 1) {
          final label = field?.label ?? key;
          refs.add(
            _ImageRef(
              label: paths.length == 1 ? label : '$label ${index + 1}',
              path: paths[index],
            ),
          );
        }
      }
    }
    return refs;
  }

  String? _fieldValueKey(Map<String, String> values, TemplateField field) {
    final normalizedLabel = _normalizedFieldKey(field.label);
    final normalizedId = _normalizedFieldKey(field.id);
    for (final key in values.keys) {
      final normalizedKey = _normalizedFieldKey(key);
      if (key == field.label ||
          key == field.id ||
          normalizedKey == normalizedLabel ||
          normalizedKey == normalizedId) {
        return key;
      }
    }
    return null;
  }

  List<String> _imagePathsFor(TemplateField? field, String key, String value) {
    if (field?.type == TemplateFieldType.image) {
      return parseImageFieldValue(value);
    }
    final paths = parseImageFieldValue(value);
    if (paths.isEmpty) return const <String>[];
    if (paths.every(looksLikeImageAssetPath)) return paths;
    return const <String>[];
  }

  Widget _fieldRow(
    String key,
    String value,
    TemplateField? field, {
    required bool last,
  }) {
    final mono = _isMono(field);
    final mask = field?.type == TemplateFieldType.password;
    final label = field?.label ?? key;
    return CopyRow(
      label: label,
      value: value,
      accent: widget.accent,
      accentSoft: widget.accentSoft,
      mono: mono,
      mask: mask,
      last: last,
      onCopied: (_) {
        showOrgToast(
          context,
          message: 'Copied $label',
          icon: Icons.content_paste_rounded,
          background: widget.accent,
        );
      },
    );
  }

  bool _isMono(TemplateField? field) {
    if (field == null) return false;
    switch (field.type) {
      case TemplateFieldType.password:
      case TemplateFieldType.url:
      case TemplateFieldType.ip:
      case TemplateFieldType.regex:
        return true;
      case TemplateFieldType.number:
        return (field.digits ?? 0) > 0;
      default:
        return false;
    }
  }

  void _onCopyAll(NoteRecord record) {
    final label = record.label.isEmpty ? 'record' : record.label;
    showOrgToast(
      context,
      message: 'Copied $label',
      icon: Icons.content_copy_rounded,
      background: widget.accent,
    );
  }

  Future<void> _showMoreMenu(BuildContext context) async {
    final palette = OrgPaletteScope.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final selected = await showMenu<_ViewerMenu>(
      context: context,
      color: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: RelativeRect.fromRect(
        Rect.fromLTWH(overlay.size.width - 64, 56, 48, 48),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<_ViewerMenu>>[
        _menuItem(
          _ViewerMenu.editTemplate,
          'Edit template',
          Icons.tune_rounded,
          palette,
        ),
        _menuItem(
          _ViewerMenu.rawSource,
          'Raw source',
          Icons.code_rounded,
          palette,
        ),
        const PopupMenuDivider(),
        _menuItem(
          _ViewerMenu.delete,
          'Move to trash',
          Icons.delete_outline_rounded,
          palette,
          destructive: true,
        ),
      ],
    );
    if (!context.mounted || selected == null) return;
    switch (selected) {
      case _ViewerMenu.editTemplate:
        _openTemplateBuilder(context);
      case _ViewerMenu.rawSource:
        _openRawSource(context);
      case _ViewerMenu.delete:
        _delete(context);
    }
  }

  PopupMenuItem<_ViewerMenu> _menuItem(
    _ViewerMenu value,
    String label,
    IconData icon,
    OrgPalette palette, {
    bool destructive = false,
  }) {
    final color = destructive ? palette.danger : palette.text;
    return PopupMenuItem<_ViewerMenu>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ViewerMenu { editTemplate, rawSource, delete }

String _normalizedFieldKey(String value) {
  return value
      .replaceAll('*', '')
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}

class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({
    required this.note,
    required this.template,
    required this.category,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.compact,
    required this.onBack,
    required this.onShare,
    required this.onEdit,
    required this.onMore,
  });

  final Note note;
  final Template? template;
  final Category? category;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final bool compact;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final fieldsCount = template?.fields.length ?? 0;
    final recordsCount = note.records.length;
    final mq = MediaQuery.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accentSoft, accentSoft.withAlpha(60), palette.bg],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          compact ? 10 : 14,
          mq.padding.top + (compact ? 6 : 10),
          compact ? 10 : 14,
          compact ? 18 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OrgIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                  tooltip: 'Back',
                  size: 38,
                ),
                const Spacer(),
                OrgIconButton(
                  icon: Icons.ios_share_rounded,
                  onPressed: onShare,
                  tooltip: 'Share',
                  size: 38,
                ),
                const SizedBox(width: 6),
                OrgIconButton(
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  size: 38,
                ),
                const SizedBox(width: 6),
                OrgIconButton(
                  icon: Icons.more_horiz_rounded,
                  onPressed: onMore,
                  tooltip: 'More',
                  size: 38,
                ),
              ],
            ),
            SizedBox(height: compact ? 12 : 18),
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: compact ? 4 : 6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TemplateChip(
                    template: template,
                    accent: accent,
                    accentSoft: accentSoft,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.icon != null && note.icon!.isNotEmpty) ...[
                        Text(
                          note.icon!,
                          style: TextStyle(
                            fontSize: compact ? 28 : 34,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled note' : note.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: palette.text,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.02,
                                fontSize: compact ? 22 : 26,
                              ),
                        ),
                      ),
                      if (note.isPinned)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(start: 6),
                          child: Icon(
                            Icons.push_pin_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _MetaRow(
                    note: note,
                    fieldsCount: fieldsCount,
                    recordsCount: recordsCount,
                    accent: accent,
                    palette: palette,
                  ),
                  if (note.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in note.tags)
                          _TagPill(tag: tag, palette: palette),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.template,
    required this.accent,
    required this.accentSoft,
  });

  final Template? template;
  final Color accent;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) {
    final name = template?.name ?? 'No template';
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 8),
          Text(
            name.toUpperCase(),
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.note,
    required this.fieldsCount,
    required this.recordsCount,
    required this.accent,
    required this.palette,
  });

  final Note note;
  final int fieldsCount;
  final int recordsCount;
  final Color accent;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    parts.add(
      _dot(
        'Updated ${formatRelativeTime(note.updatedAt)}',
        palette.textSecondary,
      ),
    );
    if (recordsCount > 0) {
      parts.add(_separator(palette));
      parts.add(
        _dot(
          '$recordsCount record${recordsCount == 1 ? '' : 's'}',
          palette.textSecondary,
        ),
      );
    }
    if (fieldsCount > 0) {
      parts.add(_separator(palette));
      parts.add(
        _dot(
          '$fieldsCount field${fieldsCount == 1 ? '' : 's'}',
          palette.textSecondary,
        ),
      );
    }
    if (note.isFavorite) {
      parts.add(_separator(palette));
      parts.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: 14, color: accent),
            const SizedBox(width: 4),
            Text(
              'favorite',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: parts);
  }

  Widget _dot(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _separator(OrgPalette palette) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          color: palette.textTertiary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag, required this.palette});

  final String tag;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 9,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
        color: palette.surface.withAlpha(160),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          color: palette.textSecondary,
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BodyBlock extends StatelessWidget {
  const _BodyBlock({required this.body, required this.palette});

  final String body;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: SelectableText(
        body,
        style: TextStyle(color: palette.text, fontSize: 14, height: 1.45),
      ),
    );
  }
}

class _ImageRef {
  const _ImageRef({required this.label, required this.path});

  final String label;
  final String path;
}

class _ImageFieldRow extends StatefulWidget {
  const _ImageFieldRow({
    required this.label,
    required this.paths,
    required this.accent,
    required this.accentSoft,
    required this.assetRepository,
    required this.imageRefs,
    required this.imageIndex,
  });

  final String label;
  final List<String> paths;
  final Color accent;
  final Color accentSoft;
  final AssetRepository assetRepository;
  final List<_ImageRef> imageRefs;
  final int imageIndex;

  @override
  State<_ImageFieldRow> createState() => _ImageFieldRowState();
}

class _ImageFieldRowState extends State<_ImageFieldRow> {
  final Map<String, Future<Uint8List>> _futures = <String, Future<Uint8List>>{};

  Future<Uint8List>? _futureFor(String path) {
    if (path.isEmpty) return null;
    return _futures.putIfAbsent(
      path,
      () => widget.assetRepository.readAssetBytes(path),
    );
  }

  Future<void> _copyPath(BuildContext context) async {
    if (widget.paths.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(text: encodeImageFieldValue(widget.paths)),
    );
    if (!context.mounted) return;
    showOrgToast(
      context,
      message: 'Copied ${widget.label}',
      icon: Icons.content_paste_rounded,
      background: widget.accent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 4,
        vertical: 4,
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: palette.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label.toUpperCase(),
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.06,
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _copyPath(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: widget.paths.isEmpty
                          ? Colors.transparent
                          : widget.accentSoft,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: widget.paths.isEmpty
                            ? palette.border
                            : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: widget.paths.isEmpty
                          ? palette.textTertiary
                          : widget.accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < widget.paths.length; index += 1) ...[
              if (index > 0) const SizedBox(height: 8),
              _ViewerImageThumb(
                openKey: ValueKey('viewer-image-${widget.paths[index]}'),
                future: _futureFor(widget.paths[index]),
                palette: palette,
                accent: widget.accent,
                onOpen: () => _openPreviewAt(context, index),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPreviewAt(BuildContext context, int offset) {
    final target = widget.imageIndex + offset;
    if (target < 0 || target >= widget.imageRefs.length) return;
    final palette = OrgPaletteScope.of(context);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return _ImageGalleryDialog(
          imageRefs: widget.imageRefs,
          initialIndex: target,
          assetRepository: widget.assetRepository,
          accent: widget.accent,
          palette: palette,
        );
      },
    );
  }
}

class _ViewerImageThumb extends StatelessWidget {
  const _ViewerImageThumb({
    required this.openKey,
    required this.future,
    required this.palette,
    required this.accent,
    required this.onOpen,
  });

  final Key openKey;
  final Future<Uint8List>? future;
  final OrgPalette palette;
  final Color accent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return _ThumbFrame(
        palette: palette,
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: palette.textSecondary,
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _ThumbFrame(
            palette: palette,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ThumbFrame(
            palette: palette,
            child: Icon(
              Icons.broken_image_outlined,
              size: 28,
              color: palette.danger,
            ),
          );
        }
        final bytes = snapshot.data!;
        return GestureDetector(
          key: openKey,
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: palette.surfaceHigh,
                alignment: Alignment.center,
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThumbFrame extends StatelessWidget {
  const _ThumbFrame({required this.palette, required this.child});

  final OrgPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({
    required this.imageRefs,
    required this.initialIndex,
    required this.assetRepository,
    required this.accent,
    required this.palette,
  });

  final List<_ImageRef> imageRefs;
  final int initialIndex;
  final AssetRepository assetRepository;
  final Color accent;
  final OrgPalette palette;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, Future<Uint8List>> _cache = <int, Future<Uint8List>>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageRefs.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<Uint8List> _bytesFor(int index) {
    return _cache.putIfAbsent(
      index,
      () => widget.assetRepository.readAssetBytes(widget.imageRefs[index].path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final total = widget.imageRefs.length;
    final ref = widget.imageRefs[_currentIndex];
    return Dialog.fullscreen(
      backgroundColor: palette.bg,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: total,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return FutureBuilder<Uint8List>(
                  future: _bytesFor(index),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.accent,
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: palette.danger,
                        ),
                      );
                    }
                    return InteractiveViewer(
                      minScale: 0.7,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + 10,
            start: 12,
            child: OrgIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Close',
              size: 40,
            ),
          ),
          if (total > 1)
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + 16,
              end: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.surface.withAlpha(220),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '${_currentIndex + 1} / $total',
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          PositionedDirectional(
            bottom: MediaQuery.paddingOf(context).bottom + 22,
            start: 24,
            end: 24,
            child: IgnorePointer(
              child: Text(
                ref.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.04,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid layout tile
// ---------------------------------------------------------------------------

class _GridRecordTile extends StatelessWidget {
  const _GridRecordTile({
    required this.index,
    required this.record,
    required this.template,
    required this.accent,
    required this.accentSoft,
  });

  final int index;
  final NoteRecord record;
  final Template? template;
  final Color accent;
  final Color accentSoft;

  String _fieldLabel(String key) {
    if (template == null) return key;
    for (final f in template!.fields) {
      if (f.id == key || f.label == key) return f.label;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final label = record.label.isEmpty ? 'Record ${index + 1}' : record.label;
    final filled =
        record.values.values.where((v) => v.trim().isNotEmpty).length;

    final previews = <(String, String)>[];
    for (final e in record.values.entries) {
      if (e.value.trim().isEmpty) continue;
      if (previews.length >= 3) break;
      previews.add((_fieldLabel(e.key), e.value));
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
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
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$filled field${filled == 1 ? '' : 's'}',
                style: TextStyle(
                  color: palette.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              height: 1.2,
            ),
          ),
          if (previews.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final p in previews.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${p.$1}: ${p.$2}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table layout
// ---------------------------------------------------------------------------

class _TableRecordsList extends StatelessWidget {
  const _TableRecordsList({
    required this.records,
    required this.template,
    required this.accent,
    required this.accentSoft,
  });

  final List<NoteRecord> records;
  final Template? template;
  final Color accent;
  final Color accentSoft;

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
        children: [
          for (var i = 0; i < records.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: palette.border,
                indent: 16,
                endIndent: 16,
              ),
            _TableRow(
              index: i,
              record: records[i],
              template: template,
              accent: accent,
              accentSoft: accentSoft,
            ),
          ],
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.index,
    required this.record,
    required this.template,
    required this.accent,
    required this.accentSoft,
  });

  final int index;
  final NoteRecord record;
  final Template? template;
  final Color accent;
  final Color accentSoft;

  String _fieldLabel(String key) {
    if (template == null) return key;
    for (final f in template!.fields) {
      if (f.id == key || f.label == key) return f.label;
    }
    return key;
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final label = record.label.isEmpty ? 'Record ${index + 1}' : record.label;

    final summary = <String>[];
    for (final e in record.values.entries) {
      if (e.value.trim().isEmpty) continue;
      if (summary.length >= 4) break;
      summary.add('${_fieldLabel(e.key)}: ${e.value}');
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
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
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    summary.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
