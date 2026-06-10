import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
import 'package:organote/services/logging/error_log_service.dart';
import 'package:organote/services/storage/file_store.dart';
import 'package:organote/ui/screens/settings/settings_screen.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:organote/ui/state/library_provider.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';
import 'package:organote/ui/theme/density.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SettingsScreen renders live settings dashboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefs = await _prefs();
    final snapshot = _snapshot();

    await tester.pumpWidget(
      _SettingsHarness(
        prefs: prefs,
        snapshot: snapshot,
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: _FakeSyncRepo(
          status: SyncStatus(
            phase: SyncPhase.complete,
            signedIn: true,
            lastSyncAt: DateTime.now().toUtc(),
            pendingChanges: 2,
            conflictCount: 1,
          ),
        ),
        complianceRepository: _FakeComplianceRepo(
          summary: snapshot.complianceSummary,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sync'), findsOneWidget);
    expect(find.text('Customization'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Compliance'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Open trash'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Review issues'), findsOneWidget);
    expect(find.text('Google Drive'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('memory'), findsWidgets);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('SettingsScreen updates customization and sync controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefs = await _prefs();
    final syncRepo = _FakeSyncRepo(
      status: const SyncStatus(phase: SyncPhase.idle, signedIn: true),
    );

    await tester.pumpWidget(
      _SettingsHarness(
        prefs: prefs,
        snapshot: _snapshot(),
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: syncRepo,
        complianceRepository: _FakeComplianceRepo(
          summary: _snapshot().complianceSummary,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(
      prefs.getInt('organote.ui.themePreference'),
      ThemePreference.light.index,
    );

    await tester.drag(find.byType(Slider), const Offset(180, 0));
    await tester.pump();
    expect(
      prefs.getDouble('organote.ui.accentHue'),
      isNot(OrgAccents.mint.hue),
    );

    await tester.tap(find.text('Sync now'));
    await tester.pump();
    expect(syncRepo.syncCalls, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('settings.errorLog.switch')),
    );
    await tester.pump();
    expect(prefs.getBool(ErrorLogService.enabledPreferenceKey), isTrue);
  });

  testWidgets('SettingsScreen uses one Drive action while disconnected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final prefs = await _prefs();
    final syncRepo = _FakeSyncRepo(
      status: const SyncStatus(phase: SyncPhase.idle),
    );

    await tester.pumpWidget(
      _SettingsHarness(
        prefs: prefs,
        snapshot: _snapshot(),
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: syncRepo,
        complianceRepository: _FakeComplianceRepo(
          summary: _snapshot().complianceSummary,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Connect Drive'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);

    await tester.tap(find.text('Connect Drive'));
    await tester.pump();

    expect(syncRepo.signInCalls, 1);
    expect(syncRepo.syncCalls, 0);
  });

  testWidgets('SettingsScreen warns about Drive overwrites after connect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final syncRepo = _FakeSyncRepo(
      status: const SyncStatus(phase: SyncPhase.idle),
      overwriteWarnings: <SyncOverwriteWarning>[
        SyncOverwriteWarning(
          relativePath: 'notes/prod.md',
          itemType: SyncOverwriteItemType.note,
          localModifiedAt: DateTime.utc(2026, 1, 1, 9),
          remoteModifiedAt: DateTime.utc(2026, 1, 2, 9),
        ),
        SyncOverwriteWarning(
          relativePath: 'templates/server.md',
          itemType: SyncOverwriteItemType.template,
          localModifiedAt: DateTime.utc(2026, 1, 3, 9),
          remoteModifiedAt: DateTime.utc(2026, 1, 2, 9),
        ),
        // No-ledger divergence (reconciler state 7): both copies changed but
        // share a modified time, so neither side is provably newer.
        SyncOverwriteWarning(
          relativePath: 'notes/diverged.md',
          itemType: SyncOverwriteItemType.note,
          localModifiedAt: DateTime.utc(2026, 1, 2, 9),
          remoteModifiedAt: DateTime.utc(2026, 1, 2, 9),
        ),
      ],
    );

    await tester.pumpWidget(
      _SettingsHarness(
        prefs: await _prefs(),
        snapshot: _snapshot(),
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: syncRepo,
        complianceRepository: _FakeComplianceRepo(
          summary: _snapshot().complianceSummary,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Connect Drive'));
    await tester.pumpAndSettle();

    expect(syncRepo.signInCalls, 1);
    expect(syncRepo.syncCalls, 0);
    expect(
      find.text('Remote changes will replace local files'),
      findsOneWidget,
    );
    expect(find.text('notes/prod.md'), findsOneWidget);
    expect(find.text('templates/server.md'), findsOneWidget);
    expect(find.text('Drive newer'), findsOneWidget);
    expect(find.text('Local newer'), findsOneWidget);
    // Ambiguous newer side (equal timestamps, diverged content) renders as a
    // Conflict pill rather than the misleading "Same time".
    expect(find.text('notes/diverged.md'), findsOneWidget);
    expect(find.text('Conflict'), findsOneWidget);
    // The one local-newer row is a data-loss case, so the dialog calls it out.
    expect(
      find.text('1 file has newer local edits that will be replaced by Drive.'),
      findsOneWidget,
    );
    // The dialog stays informational: it points back to Sync now, not a write.
    expect(find.textContaining('Nothing changes yet'), findsOneWidget);
  });

  testWidgets('SettingsScreen distinguishes reconnect from changing storage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _FakeFileStore(
      status: const StorageStatus.unavailable(
        reason: StorageUnavailableReason.permissionDenied,
        message: 'Reconnect folder access for Organote.',
        rootLabel: 'Organote (saved folder)',
      ),
    );

    await tester.pumpWidget(
      _SettingsHarness(
        prefs: await _prefs(),
        snapshot: _snapshot(),
        fileStore: store,
        syncRepository: _FakeSyncRepo(
          status: const SyncStatus(phase: SyncPhase.idle, signedIn: true),
        ),
        complianceRepository: _FakeComplianceRepo(
          summary: _snapshot().complianceSummary,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Reconnect folder'), findsOneWidget);

    await tester.tap(find.text('Reconnect folder'));
    await tester.pump();

    expect(store.chooseCalls, 1);
  });

  testWidgets('SettingsScreen opens trash and restores an entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final snapshot = _snapshot();
    final noteRepo = _FakeNoteRepo();
    await tester.pumpWidget(
      _SettingsHarness(
        prefs: await _prefs(),
        snapshot: snapshot,
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: _FakeSyncRepo(
          status: const SyncStatus(phase: SyncPhase.idle, signedIn: true),
        ),
        complianceRepository: _FakeComplianceRepo(
          summary: snapshot.complianceSummary,
        ),
        noteRepository: noteRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open trash'));
    await tester.pumpAndSettle();

    expect(find.text('prod.md'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pump();

    expect(noteRepo.restoredIds, <String>['trash-1']);
  });

  testWidgets('Compliance review accepts rename-copy suggestions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final note = Note(
      id: 'prod',
      title: 'Prod',
      templateId: 'server',
      templateName: 'Server',
      templateVersion: 1,
      records: const <NoteRecord>[
        NoteRecord(
          label: 'Server 1',
          values: <String, String>{'Old Host': 'db'},
        ),
      ],
    );
    final snapshot = LibrarySnapshot(
      notes: <Note>[note],
      templates: const <Template>[
        Template(id: 'server', name: 'Server', version: 1, fields: []),
      ],
      complianceSummary: const ComplianceSummary(
        issues: <ComplianceIssue>[
          ComplianceIssue(
            id: 'rename-1',
            type: ComplianceIssueType.renameCopySuggestion,
            severity: ComplianceSeverity.info,
            message: 'Copy "Old Host" into renamed field "Host".',
            noteId: 'prod',
            templateId: 'server',
            fieldLabel: 'Host',
            legacyFieldLabel: 'Old Host',
          ),
        ],
      ),
    );
    final noteRepo = _FakeNoteRepo(note: note);
    await tester.pumpWidget(
      _SettingsHarness(
        prefs: await _prefs(),
        snapshot: snapshot,
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: _FakeSyncRepo(
          status: const SyncStatus(phase: SyncPhase.idle, signedIn: true),
        ),
        complianceRepository: _FakeComplianceRepo(
          summary: snapshot.complianceSummary,
        ),
        noteRepository: noteRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Review issues'));
    await tester.pumpAndSettle();

    expect(
      find.text('Copy "Old Host" into renamed field "Host".'),
      findsOneWidget,
    );

    await tester.tap(find.text('Accept rename'));
    await tester.pump();

    expect(noteRepo.savedInputs, hasLength(1));
    expect(noteRepo.savedInputs.single.records.single.values['Host'], 'db');
  });

  testWidgets('Compliance review persists ignored issues', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final snapshot = _snapshot();
    final complianceRepo = _FakeComplianceRepo(
      summary: snapshot.complianceSummary,
    );
    await tester.pumpWidget(
      _SettingsHarness(
        prefs: await _prefs(),
        snapshot: snapshot,
        fileStore: _FakeFileStore(
          status: const StorageStatus.available(rootLabel: 'memory'),
        ),
        syncRepository: _FakeSyncRepo(
          status: const SyncStatus(phase: SyncPhase.idle, signedIn: true),
        ),
        complianceRepository: complianceRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Review issues'));
    await tester.pumpAndSettle();
    expect(find.text('Missing required field'), findsWidgets);

    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    expect(complianceRepo.ignoredIds, <String>['issue-1']);
    expect(find.text('Missing required field'), findsNothing);
  });
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return SharedPreferences.getInstance();
}

LibrarySnapshot _snapshot() {
  return LibrarySnapshot(
    notes: const <Note>[
      Note(id: 'prod', title: 'Prod', records: <NoteRecord>[]),
      Note(id: 'stage', title: 'Stage', records: <NoteRecord>[]),
    ],
    templates: const <Template>[
      Template(id: 'server', name: 'Server', version: 1, fields: []),
    ],
    trash: <TrashEntry>[
      TrashEntry(
        id: 'trash-1',
        originalPath: 'notes/prod.md',
        trashPath: 'trash/prod.md',
        deletedAt: DateTime(2026, 5, 20, 9),
        type: TrashEntryType.note,
      ),
    ],
    complianceSummary: const ComplianceSummary(
      issues: <ComplianceIssue>[
        ComplianceIssue(
          id: 'issue-1',
          type: ComplianceIssueType.missingRequiredField,
          severity: ComplianceSeverity.warning,
          message: 'Missing required field',
        ),
      ],
    ),
  );
}

class _SettingsHarness extends StatelessWidget {
  const _SettingsHarness({
    required this.prefs,
    required this.snapshot,
    required this.fileStore,
    required this.syncRepository,
    required this.complianceRepository,
    this.noteRepository,
  });

  final SharedPreferences prefs;
  final LibrarySnapshot snapshot;
  final FileStore fileStore;
  final SyncRepository syncRepository;
  final ComplianceRepository complianceRepository;
  final NoteRepository? noteRepository;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        fileStoreProvider.overrideWithValue(fileStore),
        librarySnapshotProvider.overrideWithValue(snapshot),
        libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepo(snapshot)),
        syncRepositoryProvider.overrideWithValue(syncRepository),
        complianceRepositoryProvider.overrideWithValue(complianceRepository),
        errorLogServiceProvider.overrideWithValue(
          ErrorLogService(fileStore: fileStore, preferences: prefs),
        ),
        if (noteRepository != null)
          noteRepositoryProvider.overrideWithValue(noteRepository!),
      ],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: const OrgDensity(
            level: OrgDensityLevel.comfortable,
            child: SettingsScreen(),
          ),
        ),
      ),
    );
  }
}

class _FakeNoteRepo implements NoteRepository {
  _FakeNoteRepo({this.note});

  final Note? note;
  final List<String> restoredIds = <String>[];
  final List<String> purgedIds = <String>[];
  final List<NoteInput> savedInputs = <NoteInput>[];

  @override
  Future<Note?> getNote(String id) async => note?.id == id ? note : null;

  @override
  Future<String> getRawSource(String id) async => '';

  @override
  Future<void> purgeTrashEntry(String trashEntryId) async {
    purgedIds.add(trashEntryId);
  }

  @override
  Future<void> restoreFromTrash(String trashEntryId) async {
    restoredIds.add(trashEntryId);
  }

  @override
  Future<Note> saveRawSource(String id, String source) async {
    return note!;
  }

  @override
  Future<Note> saveStructuredNote(NoteInput input) async {
    savedInputs.add(input);
    return Note(
      id: input.id ?? 'saved',
      title: input.title,
      records: input.records,
    );
  }

  @override
  Future<void> setFavorite(String noteId, bool value) async {}

  @override
  Future<void> setPinned(String noteId, bool value) async {}

  @override
  Future<void> softDeleteNote(String id) async {}

  @override
  Stream<List<TrashEntry>> watchTrash() =>
      const Stream<List<TrashEntry>>.empty();
}

class _FakeLibraryRepo implements LibraryRepository {
  const _FakeLibraryRepo(this.snapshot);

  final LibrarySnapshot snapshot;

  @override
  Future<LibrarySnapshot> reload() async => snapshot;

  @override
  Stream<LibrarySnapshot> watchLibrary() =>
      Stream<LibrarySnapshot>.value(snapshot);
}

class _FakeSyncRepo implements SyncRepository {
  _FakeSyncRepo({
    required this.status,
    this.overwriteWarnings = const <SyncOverwriteWarning>[],
  });

  final SyncStatus status;
  final List<SyncOverwriteWarning> overwriteWarnings;
  int syncCalls = 0;
  int signInCalls = 0;

  @override
  Future<void> prepareGoogleDriveSignIn() async {}

  @override
  Future<void> signInGoogleDrive() async {
    signInCalls += 1;
  }

  @override
  Future<List<SyncOverwriteWarning>> previewRemoteOverwrites() async {
    return overwriteWarnings;
  }

  @override
  Future<void> syncNow() async {
    syncCalls += 1;
  }

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream<SyncStatus>.value(status);
}

class _FakeComplianceRepo implements ComplianceRepository {
  _FakeComplianceRepo({required this.summary});

  final ComplianceSummary summary;
  final List<String> ignoredIds = <String>[];
  final List<String> restoredIds = <String>[];

  @override
  Future<ComplianceSummary> scanNow() async => summary;

  @override
  Stream<ComplianceSummary> watchComplianceSummary() {
    return Stream<ComplianceSummary>.value(summary);
  }

  @override
  Future<void> ignoreIssue(String issueId) async {
    ignoredIds.add(issueId);
  }

  @override
  Future<void> restoreIgnoredIssue(String issueId) async {
    restoredIds.add(issueId);
  }
}

class _FakeFileStore implements FileStore {
  _FakeFileStore({required this.status});

  final StorageStatus status;
  final Map<String, String> textFiles = <String, String>{};
  int chooseCalls = 0;

  @override
  Future<void> chooseRootDirectory() async {
    chooseCalls += 1;
  }

  @override
  Future<void> createDirectory(String relativePath) async {}

  @override
  Future<void> delete(String relativePath, {bool recursive = false}) async {}

  @override
  Future<bool> exists(String relativePath) async {
    return textFiles.containsKey(relativePath);
  }

  @override
  Future<StorageStatus> getStatus() async => status;

  @override
  Future<void> initialize({String? rootPath}) async {}

  @override
  Future<void> ensureStructure() async {}

  @override
  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  }) async {
    return const <StoredFile>[];
  }

  @override
  Future<void> move(String fromRelativePath, String toRelativePath) async {}

  @override
  Future<List<int>> readBytes(String relativePath) async => const <int>[];

  @override
  Future<String> readText(String relativePath) async =>
      textFiles[relativePath]!;

  @override
  Future<void> writeBytes(String relativePath, List<int> bytes) async {}

  @override
  Future<void> writeText(String relativePath, String contents) async {
    textFiles[relativePath] = contents;
  }
}
