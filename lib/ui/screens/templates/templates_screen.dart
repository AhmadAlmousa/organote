import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../app/mobile_shell.dart';
import '../../app/overlay_route.dart';
import '../../state/library_provider.dart';
import '../../theme/color_tokens.dart';
import '../../theme/density.dart';
import '../../util/relative_time.dart';
import '../../widgets/org_empty_state.dart';
import '../../widgets/org_fab.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/template_card.dart';
import '../../widgets/wordmark.dart';
import '../note_editor/note_editor_screen.dart';
import '../note_viewer/note_viewer_screen.dart';
import '../template_builder/template_builder_screen.dart';

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    final library = ref.watch(librarySnapshotProvider);
    final usage = _buildUsage(library.notes);
    final templates = [...library.templates]
      ..sort((a, b) {
        final aCount = usage[a.id]?.length ?? 0;
        final bCount = usage[b.id]?.length ?? 0;
        if (aCount != bCount) return bCount.compareTo(aCount);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final used = templates
        .where((template) => (usage[template.id]?.isNotEmpty ?? false))
        .toList();
    final unused = templates
        .where((template) => (usage[template.id]?.isEmpty ?? true))
        .toList();
    final fieldCount = templates.fold<int>(
      0,
      (sum, template) => sum + template.fields.length,
    );

    final shellInset = OrgMobileChrome.bottomInsetOf(context);
    final fabBottom = shellInset + 14;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _TemplatesHeader(
                    templateCount: templates.length,
                    onCreate: () => _openTemplateBuilder(context),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
                  sliver: SliverToBoxAdapter(
                    child: _StatsBanner(
                      total: templates.length,
                      used: used.length,
                      unused: unused.length,
                      fields: fieldCount,
                    ),
                  ),
                ),
                if (templates.isEmpty)
                  SliverToBoxAdapter(
                    child: OrgEmptyState(
                      emoji: '[]',
                      message: 'No templates yet',
                      subtitle:
                          'Create a schema before capturing structured notes.',
                    ),
                  )
                else ...[
                  _TemplateSection(
                    title: 'Used templates',
                    subtitle: '${used.length} active schemas',
                    templates: used,
                    usage: usage,
                    emptyMessage: 'No templates have notes yet.',
                    onShowNotes: (template, notes) =>
                        _showAssociatedNotes(context, template, notes),
                    onCreateNote: (template) =>
                        _openNoteEditor(context, template),
                    onEdit: (template) =>
                        _openTemplateEditor(context, template),
                  ),
                  _TemplateSection(
                    title: 'Unused templates',
                    subtitle: '${unused.length} ready to use',
                    templates: unused,
                    usage: usage,
                    emptyMessage: 'Every template is already in use.',
                    onShowNotes: (template, notes) =>
                        _showAssociatedNotes(context, template, notes),
                    onCreateNote: (template) =>
                        _openNoteEditor(context, template),
                    onEdit: (template) =>
                        _openTemplateEditor(context, template),
                  ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(height: shellInset + 32),
                ),
              ],
            ),
            Positioned(
              right: 18,
              bottom: fabBottom,
              child: OrgFab(
                icon: Icons.add_box_rounded,
                tooltip: 'New template',
                size: compact ? 52 : 60,
                onPressed: () => _openTemplateBuilder(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<Note>> _buildUsage(List<Note> notes) {
    final result = <String, List<Note>>{};
    for (final note in notes) {
      final id = note.templateId;
      if (id == null || id.isEmpty) continue;
      result.putIfAbsent(id, () => <Note>[]).add(note);
    }
    for (final notes in result.values) {
      notes.sort((a, b) {
        final aDate = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }
    return result;
  }

  void _openTemplateBuilder(BuildContext context) {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(builder: (_) => const TemplateBuilderScreen()),
    );
  }

  void _openTemplateEditor(BuildContext context, Template template) {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(
        builder: (_) => TemplateBuilderScreen(templateId: template.id),
      ),
    );
  }

  void _openNoteEditor(BuildContext context, Template template) {
    Navigator.of(context).push(
      OrgOverlayRoute<void>(
        builder: (_) => NoteEditorScreen(templateId: template.id),
      ),
    );
  }

  void _showAssociatedNotes(
    BuildContext context,
    Template template,
    List<Note> notes,
  ) {
    final palette = OrgPaletteScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.54,
          minChildSize: 0.32,
          maxChildSize: 0.86,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: palette.accentSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            template.icon ?? _initialFor(template.name),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                template.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: palette.text),
                              ),
                              Text(
                                '${notes.length} associated note${notes.length == 1 ? '' : 's'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.textTertiary),
                              ),
                            ],
                          ),
                        ),
                        OrgIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: notes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return _AssociatedNoteRow(
                          note: note,
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              OrgOverlayRoute<void>(
                                builder: (_) =>
                                    NoteViewerScreen(noteId: note.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplatesHeader extends StatelessWidget {
  const _TemplatesHeader({required this.templateCount, required this.onCreate});

  final int templateCount;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final density = OrgDensity.of(context);
    final compact = density == OrgDensityLevel.compact;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 18,
        compact ? 6 : 14,
        compact ? 12 : 18,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Wordmark(size: compact ? 18 : 20),
              const Spacer(),
              OrgIconButton(
                icon: Icons.add_rounded,
                tooltip: 'New template',
                onPressed: onCreate,
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            Text(
              'Templates',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              templateCount == 0
                  ? 'shape the first structured note.'
                  : '$templateCount schema${templateCount == 1 ? '' : 's'} shaping your notes.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({
    required this.total,
    required this.used,
    required this.unused,
    required this.fields,
  });

  final int total;
  final int used;
  final int unused;
  final int fields;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final compact = OrgDensity.of(context) == OrgDensityLevel.compact;
    final stats = <_TemplateStat>[
      _TemplateStat('Total', total, Icons.dashboard_customize_rounded),
      _TemplateStat('Used', used, Icons.bolt_rounded),
      _TemplateStat('Unused', unused, Icons.inbox_rounded),
      _TemplateStat('Fields', fields, Icons.view_week_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(compact ? 16 : 20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -14,
          ),
        ],
      ),
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: Row(
        children: [
          for (var index = 0; index < stats.length; index++) ...[
            Expanded(child: _StatCell(stat: stats[index])),
            if (index != stats.length - 1)
              Container(width: 1, height: 42, color: palette.border),
          ],
        ],
      ),
    );
  }
}

class _TemplateStat {
  const _TemplateStat(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.stat});

  final _TemplateStat stat;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(stat.icon, size: 17, color: palette.accent),
        const SizedBox(height: 4),
        Text(
          '${stat.value}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.textTertiary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TemplateSection extends StatelessWidget {
  const _TemplateSection({
    required this.title,
    required this.subtitle,
    required this.templates,
    required this.usage,
    required this.emptyMessage,
    required this.onShowNotes,
    required this.onCreateNote,
    required this.onEdit,
  });

  final String title;
  final String subtitle;
  final List<Template> templates;
  final Map<String, List<Note>> usage;
  final String emptyMessage;
  final void Function(Template template, List<Note> notes) onShowNotes;
  final ValueChanged<Template> onCreateNote;
  final ValueChanged<Template> onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final compact = OrgDensity.of(context) == OrgDensityLevel.compact;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 18,
        compact ? 18 : 22,
        compact ? 12 : 18,
        0,
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate(<Widget>[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (templates.isEmpty)
            _InlineEmpty(message: emptyMessage)
          else
            for (var index = 0; index < templates.length; index++) ...[
              TemplateCard(
                template: templates[index],
                notes: usage[templates[index].id] ?? const <Note>[],
                onShowNotes: onShowNotes,
                onCreateNote: onCreateNote,
                onEdit: onEdit,
              ),
              if (index != templates.length - 1)
                SizedBox(height: compact ? 8 : 10),
            ],
        ]),
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: palette.textTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AssociatedNoteRow extends StatelessWidget {
  const _AssociatedNoteRow({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.bgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                note.icon ?? _initialFor(note.title),
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'Untitled note' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${note.records.length} record${note.records.length == 1 ? '' : 's'} / ${formatRelativeTime(note.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
          ],
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
