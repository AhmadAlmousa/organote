import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/models.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../services/storage/file_store.dart';
import '../../app/overlay_route.dart';
import '../../state/app_providers.dart';
import '../../state/library_provider.dart';
import '../../theme/color_tokens.dart';
import '../../theme/motion.dart';
import '../../util/relative_time.dart';
import '../../widgets/org_empty_state.dart';
import '../../widgets/org_icon_button.dart';
import '../../widgets/org_toast.dart';
import '../note_viewer/note_viewer_screen.dart';

class ComplianceReviewScreen extends ConsumerStatefulWidget {
  const ComplianceReviewScreen({super.key});

  @override
  ConsumerState<ComplianceReviewScreen> createState() =>
      _ComplianceReviewScreenState();
}

class _ComplianceReviewScreenState
    extends ConsumerState<ComplianceReviewScreen> {
  final Set<String> _ignoredIssueIds = <String>{};
  bool _scanBusy = false;
  bool _actionBusy = false;

  Future<void> _scanNow() async {
    if (_scanBusy) return;
    setState(() => _scanBusy = true);
    try {
      await ref.read(complianceRepositoryProvider).scanNow();
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Compliance scanned',
        icon: Icons.fact_check_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Scan failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<void> _acceptRename(ComplianceIssue issue) async {
    final noteId = issue.noteId;
    final fieldLabel = issue.fieldLabel;
    final legacyFieldLabel = issue.legacyFieldLabel;
    if (_actionBusy ||
        noteId == null ||
        fieldLabel == null ||
        legacyFieldLabel == null) {
      return;
    }
    setState(() => _actionBusy = true);
    try {
      final noteRepo = ref.read(noteRepositoryProvider);
      final note = await noteRepo.getNote(noteId);
      if (note == null) {
        throw StateError('Note not found');
      }
      var changed = false;
      final records = note.records.map((record) {
        final current = record.values[fieldLabel];
        final legacy = record.values[legacyFieldLabel];
        if ((current == null || current.trim().isEmpty) &&
            legacy != null &&
            legacy.trim().isNotEmpty) {
          changed = true;
          final values = Map<String, String>.from(record.values)
            ..[fieldLabel] = legacy;
          return record.copyWith(values: values);
        }
        return record;
      }).toList();
      if (!changed) {
        if (!mounted) return;
        showOrgToast(
          context,
          message: 'No matching value to copy',
          icon: Icons.info_outline_rounded,
        );
        return;
      }
      await noteRepo.saveStructuredNote(
        NoteInput(
          id: note.id,
          title: note.title,
          templateId: note.templateId,
          templateName: note.templateName,
          templateVersion: note.templateVersion,
          icon: note.icon,
          tags: note.tags,
          categoryPath: note.categoryPath,
          records: records,
          body: note.body,
          isPinned: note.isPinned,
          isFavorite: note.isFavorite,
        ),
      );
      await ref.read(libraryRepositoryProvider).reload();
      if (!mounted) return;
      setState(() => _ignoredIssueIds.add(issue.id));
      showOrgToast(
        context,
        message: 'Renamed value copied',
        icon: Icons.auto_fix_high_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Rename action failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  void _openNote(String? noteId) {
    if (noteId == null) return;
    Navigator.of(context).push(
      OrgOverlayRoute<void>(builder: (_) => NoteViewerScreen(noteId: noteId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(librarySnapshotProvider);
    final activeIssues = snapshot.complianceSummary.issues
        .where(
          (issue) => !issue.ignored && !_ignoredIssueIds.contains(issue.id),
        )
        .toList();
    final grouped = _groupIssues(activeIssues);

    return _PhaseScaffold(
      title: 'Compliance',
      subtitle: '${activeIssues.length} active issues',
      icon: Icons.fact_check_rounded,
      trailing: OrgIconButton(
        icon: _scanBusy ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
        tooltip: 'Scan now',
        onPressed: _scanBusy ? null : _scanNow,
      ),
      slivers: [
        if (activeIssues.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: OrgEmptyState(
              emoji: '✓',
              message: 'All caught up',
              subtitle: 'No active template or note issues.',
            ),
          )
        else
          SliverList.separated(
            itemCount: grouped.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final group = grouped[index];
              return _IssueGroupCard(
                group: group,
                note: _findNote(snapshot.notes, group.noteId),
                actionBusy: _actionBusy,
                onOpenNote: () => _openNote(group.noteId),
                onIgnore: (issue) =>
                    setState(() => _ignoredIssueIds.add(issue.id)),
                onAcceptRename: _acceptRename,
              );
            },
          ),
      ],
    );
  }
}

class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  final Set<String> _busyIds = <String>{};
  bool _emptying = false;

  Future<void> _restore(TrashEntry entry) async {
    if (_busyIds.contains(entry.id)) return;
    setState(() => _busyIds.add(entry.id));
    try {
      await ref.read(noteRepositoryProvider).restoreFromTrash(entry.id);
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Restored from trash',
        icon: Icons.restore_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Restore failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(entry.id));
    }
  }

  Future<void> _purge(TrashEntry entry) async {
    if (_busyIds.contains(entry.id)) return;
    final confirmed = await _confirmSheet(
      context,
      title: 'Purge item?',
      message: 'This permanently removes ${_basename(entry.originalPath)}.',
      action: 'Purge',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyIds.add(entry.id));
    try {
      await ref.read(noteRepositoryProvider).purgeTrashEntry(entry.id);
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Trash item purged',
        icon: Icons.delete_forever_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Purge failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(entry.id));
    }
  }

  Future<void> _emptyTrash(List<TrashEntry> entries) async {
    if (_emptying || entries.isEmpty) return;
    final confirmed = await _confirmSheet(
      context,
      title: 'Empty trash?',
      message: 'This permanently removes ${entries.length} trashed items.',
      action: 'Empty trash',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _emptying = true);
    try {
      final repo = ref.read(noteRepositoryProvider);
      for (final entry in entries) {
        await repo.purgeTrashEntry(entry.id);
      }
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Trash emptied',
        icon: Icons.delete_sweep_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Empty trash failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _emptying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [...ref.watch(librarySnapshotProvider).trash]
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return _PhaseScaffold(
      title: 'Trash',
      subtitle: '${entries.length} recoverable items',
      icon: Icons.delete_outline_rounded,
      trailing: OrgIconButton(
        icon: _emptying
            ? Icons.hourglass_top_rounded
            : Icons.delete_sweep_rounded,
        tooltip: 'Empty trash',
        onPressed: entries.isEmpty || _emptying
            ? null
            : () => _emptyTrash(entries),
      ),
      slivers: [
        if (entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: OrgEmptyState(
              emoji: '∅',
              message: 'Trash is empty',
              subtitle: 'Deleted notes and templates will wait here.',
            ),
          )
        else
          SliverList.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _TrashEntryCard(
                entry: entry,
                busy: _busyIds.contains(entry.id),
                onRestore: () => _restore(entry),
                onPurge: () => _purge(entry),
              );
            },
          ),
      ],
    );
  }
}

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;

  Future<void> _exportBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(backupRepositoryProvider).createBackupZip();
      final now = DateTime.now().toUtc();
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}-${_two(now.hour)}${_two(now.minute)}';
      await FilePicker.saveFile(
        dialogTitle: 'Save Organote backup',
        fileName: 'organote-backup-$stamp.zip',
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
        bytes: Uint8List.fromList(bytes),
      );
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Backup exported',
        icon: Icons.archive_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Backup export failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Choose Organote backup',
        type: FileType.custom,
        allowedExtensions: const <String>['zip'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('Backup bytes unavailable');
      }
      if (!mounted) return;
      final summary = _BackupSummary.fromZip(bytes);
      final confirmed = await _confirmBackupRestore(
        context,
        file.name,
        summary,
      );
      if (!confirmed || !mounted) return;
      await ref.read(backupRepositoryProvider).restoreBackupZip(bytes);
      await ref.read(libraryRepositoryProvider).reload();
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Backup restored',
        icon: Icons.restore_rounded,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Backup restore failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(librarySnapshotProvider);
    return _PhaseScaffold(
      title: 'Backup',
      subtitle:
          '${snapshot.notes.length} notes · ${snapshot.templates.length} templates',
      icon: Icons.archive_rounded,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _MaintenancePanel(
                icon: Icons.download_rounded,
                title: 'Export ZIP',
                subtitle: 'Templates, notes, assets, trash, and app metadata.',
                actionLabel: _busy ? 'Working' : 'Export backup',
                actionIcon: _busy
                    ? Icons.hourglass_top_rounded
                    : Icons.archive_rounded,
                onAction: _busy ? null : _exportBackup,
              ),
              const SizedBox(height: 12),
              _MaintenancePanel(
                icon: Icons.upload_file_rounded,
                title: 'Restore ZIP',
                subtitle: 'Preview the archive summary before committing it.',
                actionLabel: _busy ? 'Working' : 'Restore backup',
                actionIcon: _busy
                    ? Icons.hourglass_top_rounded
                    : Icons.restore_page_rounded,
                onAction: _busy ? null : _restoreBackup,
              ),
              const SizedBox(height: 12),
              _SnapshotSummary(snapshot: snapshot),
            ],
          ),
        ),
      ],
    );
  }
}

class DangerZoneScreen extends ConsumerStatefulWidget {
  const DangerZoneScreen({super.key});

  @override
  ConsumerState<DangerZoneScreen> createState() => _DangerZoneScreenState();
}

class _DangerZoneScreenState extends ConsumerState<DangerZoneScreen> {
  final TextEditingController _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _wipeStorage() async {
    if (_busy || _confirmController.text.trim() != 'WIPE') return;
    final confirmed = await _confirmSheet(
      context,
      title: 'Wipe Organote data?',
      message: 'This deletes notes, templates, assets, trash, and metadata.',
      action: 'Wipe data',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final store = ref.read(fileStoreProvider);
      for (final directory in organoteStorageDirectories) {
        await store.delete(directory, recursive: true);
      }
      await store.ensureStructure();
      await ref.read(libraryRepositoryProvider).reload();
      if (!mounted) return;
      _confirmController.clear();
      showOrgToast(
        context,
        message: 'Organote data wiped',
        icon: Icons.warning_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } catch (_) {
      if (!mounted) return;
      showOrgToast(
        context,
        message: 'Wipe failed',
        icon: Icons.error_outline_rounded,
        background: OrgPaletteScope.of(context).danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final snapshot = ref.watch(librarySnapshotProvider);
    final enabled = _confirmController.text.trim() == 'WIPE' && !_busy;
    return _PhaseScaffold(
      title: 'Danger Zone',
      subtitle: 'Permanent local storage actions',
      icon: Icons.warning_rounded,
      accent: palette.danger,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _SnapshotSummary(snapshot: snapshot, danger: true),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.danger.withAlpha(28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.danger.withAlpha(85)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wipe local Organote data',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Type WIPE to enable the destructive action.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmController,
                      onChanged: (_) => setState(() {}),
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'WIPE',
                        prefixIcon: Icon(Icons.keyboard_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PhaseActionButton(
                      icon: _busy
                          ? Icons.hourglass_top_rounded
                          : Icons.delete_forever_rounded,
                      label: _busy ? 'Working' : 'Wipe data',
                      onTap: enabled ? _wipeStorage : null,
                      color: palette.danger,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhaseScaffold extends StatelessWidget {
  const _PhaseScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.slivers,
    this.trailing,
    this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> slivers;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final activeAccent = accent ?? palette.accent;
    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    OrgIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: activeAccent.withAlpha(34),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon, color: activeAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: palette.text,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueGroup {
  const _IssueGroup({required this.noteId, required this.issues});

  final String? noteId;
  final List<ComplianceIssue> issues;
}

class _IssueGroupCard extends StatelessWidget {
  const _IssueGroupCard({
    required this.group,
    required this.note,
    required this.actionBusy,
    required this.onOpenNote,
    required this.onIgnore,
    required this.onAcceptRename,
  });

  final _IssueGroup group;
  final Note? note;
  final bool actionBusy;
  final VoidCallback onOpenNote;
  final ValueChanged<ComplianceIssue> onIgnore;
  final ValueChanged<ComplianceIssue> onAcceptRename;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final title = note?.title ?? 'Library issue';
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadowSoft,
            blurRadius: 22,
            offset: const Offset(0, 12),
            spreadRadius: -18,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: palette.textSecondary,
          collapsedIconColor: palette.textTertiary,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.description_rounded,
              color: palette.accent,
              size: 19,
            ),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            '${group.issues.length} issue${group.issues.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: palette.textTertiary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          children: [
            for (final issue in group.issues) ...[
              _IssueRow(
                issue: issue,
                actionBusy: actionBusy,
                onOpenNote: group.noteId == null ? null : onOpenNote,
                onIgnore: () => onIgnore(issue),
                onAcceptRename:
                    issue.type == ComplianceIssueType.renameCopySuggestion
                    ? () => onAcceptRename(issue)
                    : null,
              ),
              if (issue != group.issues.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.issue,
    required this.actionBusy,
    required this.onIgnore,
    this.onOpenNote,
    this.onAcceptRename,
  });

  final ComplianceIssue issue;
  final bool actionBusy;
  final VoidCallback? onOpenNote;
  final VoidCallback onIgnore;
  final VoidCallback? onAcceptRename;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final severityColor = _severityColor(issue.severity, palette);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _issueTypeLabel(issue.type),
                  style: TextStyle(
                    color: severityColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Text(
                issue.severity.name.toUpperCase(),
                style: TextStyle(
                  color: palette.textTertiary,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.message,
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (issue.fieldLabel != null) ...[
            const SizedBox(height: 8),
            _TinyMeta(
              icon: Icons.view_week_rounded,
              label: issue.legacyFieldLabel == null
                  ? issue.fieldLabel!
                  : '${issue.legacyFieldLabel} → ${issue.fieldLabel}',
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onOpenNote != null)
                _SmallAction(
                  icon: Icons.open_in_new_rounded,
                  label: 'Open note',
                  onTap: onOpenNote,
                ),
              if (onAcceptRename != null)
                _SmallAction(
                  icon: Icons.auto_fix_high_rounded,
                  label: 'Accept rename',
                  onTap: actionBusy ? null : onAcceptRename,
                ),
              _SmallAction(
                icon: Icons.visibility_off_rounded,
                label: 'Ignore',
                onTap: onIgnore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrashEntryCard extends StatelessWidget {
  const _TrashEntryCard({
    required this.entry,
    required this.busy,
    required this.onRestore,
    required this.onPurge,
  });

  final TrashEntry entry;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final typeColor = _trashColor(entry.type, palette);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: typeColor.withAlpha(34),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_trashIcon(entry.type), color: typeColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _basename(entry.originalPath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.originalPath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textTertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _TinyMeta(
                  icon: Icons.schedule_rounded,
                  label: 'deleted ${formatRelativeTime(entry.deletedAt)} ago',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallAction(
                      icon: busy
                          ? Icons.hourglass_top_rounded
                          : Icons.restore_rounded,
                      label: busy ? 'Working' : 'Restore',
                      onTap: busy ? null : onRestore,
                    ),
                    _SmallAction(
                      icon: Icons.delete_forever_rounded,
                      label: 'Purge',
                      onTap: busy ? null : onPurge,
                      color: palette.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenancePanel extends StatelessWidget {
  const _MaintenancePanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: palette.accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PhaseActionButton(
            icon: actionIcon,
            label: actionLabel,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _SnapshotSummary extends StatelessWidget {
  const _SnapshotSummary({required this.snapshot, this.danger = false});

  final LibrarySnapshot snapshot;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final color = danger ? palette.danger : palette.accent;
    final stats = <({IconData icon, String label, String value})>[
      (
        icon: Icons.note_alt_rounded,
        label: 'Notes',
        value: '${snapshot.notes.length}',
      ),
      (
        icon: Icons.dashboard_customize_rounded,
        label: 'Templates',
        value: '${snapshot.templates.length}',
      ),
      (
        icon: Icons.delete_outline_rounded,
        label: 'Trash',
        value: '${snapshot.trash.length}',
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          for (var index = 0; index < stats.length; index += 1) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(stats[index].icon, color: color, size: 18),
                  const SizedBox(height: 5),
                  Text(
                    stats[index].value,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    stats[index].label,
                    style: TextStyle(
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (index != stats.length - 1)
              Container(width: 1, height: 42, color: palette.border),
          ],
        ],
      ),
    );
  }
}

class _PhaseActionButton extends StatefulWidget {
  const _PhaseActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  State<_PhaseActionButton> createState() => _PhaseActionButtonState();
}

class _PhaseActionButtonState extends State<_PhaseActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final disabled = widget.onTap == null;
    final color = widget.color ?? palette.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: OrgDurations.press,
        curve: OrgCurves.spring,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: disabled ? palette.surfaceHigh : color,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: disabled ? palette.textTertiary : palette.onAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: disabled ? palette.textTertiary : palette.onAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    final actionColor = color ?? palette.accent;
    final disabled = onTap == null;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 11, 7),
        decoration: BoxDecoration(
          color: disabled ? palette.surfaceHigh : actionColor.withAlpha(30),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: disabled ? palette.border : actionColor.withAlpha(80),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: disabled ? palette.textTertiary : actionColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: disabled ? palette.textTertiary : actionColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: palette.textTertiary, size: 14),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textTertiary,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupSummary {
  const _BackupSummary({
    required this.templates,
    required this.notes,
    required this.assets,
    required this.trash,
    required this.bytes,
  });

  factory _BackupSummary.fromZip(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    var templates = 0;
    var notes = 0;
    var assets = 0;
    var trash = 0;
    for (final entry in archive.files.where((entry) => entry.isFile)) {
      final name = entry.name;
      if (name.startsWith('templates/') && name.endsWith('.md')) {
        templates += 1;
      } else if (name.startsWith('notes/') && name.endsWith('.md')) {
        notes += 1;
      } else if (name.startsWith('assets/')) {
        assets += 1;
      } else if (name.startsWith('trash/')) {
        trash += 1;
      }
    }
    return _BackupSummary(
      templates: templates,
      notes: notes,
      assets: assets,
      trash: trash,
      bytes: bytes.length,
    );
  }

  final int templates;
  final int notes;
  final int assets;
  final int trash;
  final int bytes;
}

List<_IssueGroup> _groupIssues(List<ComplianceIssue> issues) {
  final grouped = <String, List<ComplianceIssue>>{};
  for (final issue in issues) {
    final key = issue.noteId ?? issue.templateId ?? issue.id;
    grouped.putIfAbsent(key, () => <ComplianceIssue>[]).add(issue);
  }
  return grouped.entries
      .map(
        (entry) =>
            _IssueGroup(noteId: entry.value.first.noteId, issues: entry.value),
      )
      .toList();
}

Note? _findNote(List<Note> notes, String? id) {
  if (id == null) return null;
  for (final note in notes) {
    if (note.id == id) return note;
  }
  return null;
}

String _issueTypeLabel(ComplianceIssueType type) {
  return switch (type) {
    ComplianceIssueType.missingRequiredField => 'Missing required field',
    ComplianceIssueType.typeMismatch => 'Type mismatch',
    ComplianceIssueType.versionDrift => 'Template version drift',
    ComplianceIssueType.orphanTemplateRef => 'Missing template',
    ComplianceIssueType.renameCopySuggestion => 'Rename copy suggestion',
  };
}

Color _severityColor(ComplianceSeverity severity, OrgPalette palette) {
  return switch (severity) {
    ComplianceSeverity.error => palette.danger,
    ComplianceSeverity.warning => palette.warning,
    ComplianceSeverity.info => palette.accent,
  };
}

IconData _trashIcon(TrashEntryType type) {
  return switch (type) {
    TrashEntryType.note => Icons.note_alt_rounded,
    TrashEntryType.template => Icons.dashboard_customize_rounded,
    TrashEntryType.asset => Icons.image_rounded,
    TrashEntryType.category => Icons.folder_rounded,
    TrashEntryType.other => Icons.insert_drive_file_rounded,
  };
}

Color _trashColor(TrashEntryType type, OrgPalette palette) {
  return switch (type) {
    TrashEntryType.note => palette.accent,
    TrashEntryType.template => palette.success,
    TrashEntryType.asset => palette.warning,
    TrashEntryType.category => palette.accentDeep,
    TrashEntryType.other => palette.textTertiary,
  };
}

String _basename(String path) {
  final cleaned = path.replaceAll('\\', '/');
  final index = cleaned.lastIndexOf('/');
  return index == -1 ? cleaned : cleaned.substring(index + 1);
}

String _two(int value) => value.toString().padLeft(2, '0');

Future<bool> _confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final palette = OrgPaletteScope.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: destructive
                        ? palette.danger
                        : palette.accent,
                    foregroundColor: palette.onAccent,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: Icon(
                    destructive
                        ? Icons.delete_forever_rounded
                        : Icons.check_rounded,
                    size: 18,
                  ),
                  label: Text(action),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

Future<bool> _confirmBackupRestore(
  BuildContext context,
  String fileName,
  _BackupSummary summary,
) async {
  final palette = OrgPaletteScope.of(context);
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restore backup?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: palette.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(label: 'Notes', value: '${summary.notes}'),
              _SummaryChip(label: 'Templates', value: '${summary.templates}'),
              _SummaryChip(label: 'Assets', value: '${summary.assets}'),
              _SummaryChip(label: 'Trash', value: '${summary.trash}'),
              _SummaryChip(label: 'Size', value: _formatBytes(summary.bytes)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.restore_page_rounded, size: 18),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = OrgPaletteScope.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: palette.bgSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
