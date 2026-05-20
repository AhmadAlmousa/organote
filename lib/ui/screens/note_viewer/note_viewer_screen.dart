import 'dart:async';

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

    final fieldsList = _buildRecordWidgets();

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
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              horizontalPad,
              compact ? 12 : 16,
              horizontalPad,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _CopyHint(accent: widget.accent, palette: palette),
            ),
          ),
          if (fieldsList.isEmpty && widget.note.body.trim().isEmpty)
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
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                horizontalPad,
                compact ? 10 : 14,
                horizontalPad,
                0,
              ),
              sliver: SliverList.separated(
                itemCount: fieldsList.length,
                separatorBuilder: (_, _) => SizedBox(height: compact ? 10 : 14),
                itemBuilder: (_, index) => fieldsList[index],
              ),
            ),
            if (widget.note.body.trim().isNotEmpty)
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
            SliverPadding(
              padding: EdgeInsetsDirectional.fromSTEB(
                horizontalPad,
                22,
                horizontalPad,
                compact ? 28 : 36,
              ),
              sliver: SliverToBoxAdapter(
                child: _ShareRow(
                  accent: widget.accent,
                  palette: palette,
                  onShare: () => _share(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildRecordWidgets() {
    final widgets = <Widget>[];
    for (var i = 0; i < widget.note.records.length; i += 1) {
      final record = widget.note.records[i];
      final fields = _buildFieldRows(record);
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

  List<Widget> _buildFieldRows(NoteRecord record) {
    final orderedKeys = <String>[];
    final templateFieldByKey = <String, TemplateField>{};
    if (widget.template != null) {
      for (final field in widget.template!.fields) {
        if (record.values.containsKey(field.label)) {
          orderedKeys.add(field.label);
          templateFieldByKey[field.label] = field;
        } else if (record.values.containsKey(field.id)) {
          orderedKeys.add(field.id);
          templateFieldByKey[field.id] = field;
        }
      }
    }
    for (final key in record.values.keys) {
      if (!orderedKeys.contains(key)) orderedKeys.add(key);
    }
    return [
      for (var i = 0; i < orderedKeys.length; i += 1)
        _fieldRow(
          orderedKeys[i],
          record.values[orderedKeys[i]] ?? '',
          templateFieldByKey[orderedKeys[i]],
          last: i == orderedKeys.length - 1,
        ),
    ];
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
    if (field?.type == TemplateFieldType.image) {
      return _ImageFieldRow(
        label: label,
        value: value,
        accent: widget.accent,
        accentSoft: widget.accentSoft,
        assetRepository: ref.read(assetRepositoryProvider),
      );
    }
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

class _CopyHint extends StatelessWidget {
  const _CopyHint({required this.accent, required this.palette});

  final Color accent;
  final OrgPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 14, color: accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Tap any field to copy its value',
              style: TextStyle(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
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

class _ShareRow extends StatefulWidget {
  const _ShareRow({
    required this.accent,
    required this.palette,
    required this.onShare,
  });

  final Color accent;
  final OrgPalette palette;
  final Future<void> Function() onShare;

  @override
  State<_ShareRow> createState() => _ShareRowState();
}

class _ShareRowState extends State<_ShareRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: () => widget.onShare(),
          child: AnimatedScale(
            scale: _down ? 0.97 : 1.0,
            duration: OrgDurations.tap,
            curve: OrgCurves.spring,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsetsDirectional.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.accent.withAlpha(90),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ios_share_rounded,
                    size: 16,
                    color: palette.onAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Share as plain text',
                    style: TextStyle(
                      color: palette.onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Frontmatter and schema are stripped automatically.',
            style: TextStyle(
              color: palette.textTertiary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageFieldRow extends StatefulWidget {
  const _ImageFieldRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.accentSoft,
    required this.assetRepository,
  });

  final String label;
  final String value;
  final Color accent;
  final Color accentSoft;
  final AssetRepository assetRepository;

  @override
  State<_ImageFieldRow> createState() => _ImageFieldRowState();
}

class _ImageFieldRowState extends State<_ImageFieldRow> {
  String? _path;
  Future<Uint8List>? _future;

  Future<Uint8List>? _futureFor(String path) {
    if (path.isEmpty) return null;
    if (_path != path) {
      _path = path;
      _future = widget.assetRepository.readAssetBytes(path);
    }
    return _future;
  }

  Future<void> _copyPath(BuildContext context) async {
    final path = widget.value.trim();
    if (path.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    showOrgToast(
      context,
      message: 'Copied ${widget.label}',
      icon: Icons.content_paste_rounded,
      background: widget.accent,
    );
  }

  void _openPreview(BuildContext context, Uint8List bytes) {
    final palette = OrgPaletteScope.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: palette.bg,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              PositionedDirectional(
                top: MediaQuery.paddingOf(dialogContext).top + 10,
                start: 12,
                child: OrgIconButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  tooltip: 'Close',
                  size: 40,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final path = widget.value.trim();
    final future = _futureFor(path);
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ViewerImageThumb(
              future: future,
              palette: palette,
              accent: widget.accent,
              onOpen: (bytes) => _openPreview(context, bytes),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label.toUpperCase(),
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.06,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path.isEmpty ? '(no image)' : path,
                    style: TextStyle(
                      color: path.isEmpty
                          ? palette.textTertiary
                          : palette.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'JetBrainsMono',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _copyPath(context),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: path.isEmpty ? Colors.transparent : widget.accentSoft,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: path.isEmpty ? palette.border : Colors.transparent,
                  ),
                ),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: path.isEmpty ? palette.textTertiary : widget.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerImageThumb extends StatelessWidget {
  const _ViewerImageThumb({
    required this.future,
    required this.palette,
    required this.accent,
    required this.onOpen,
  });

  final Future<Uint8List>? future;
  final OrgPalette palette;
  final Color accent;
  final ValueChanged<Uint8List> onOpen;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return _ThumbFrame(
        palette: palette,
        child: Icon(
          Icons.image_outlined,
          size: 20,
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
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _ThumbFrame(
            palette: palette,
            child: Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: palette.danger,
            ),
          );
        }
        final bytes = snapshot.data!;
        return GestureDetector(
          onTap: () => onOpen(bytes),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 44,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
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
    return Container(
      width: 56,
      height: 44,
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
