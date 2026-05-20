import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
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

    await tester.tap(find.byTooltip('Azure'));
    await tester.pump();
    expect(prefs.getDouble('organote.ui.accentHue'), OrgAccents.azure.hue);

    await tester.tap(find.text('Sync now'));
    await tester.pump();
    expect(syncRepo.syncCalls, 1);
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
  });

  final SharedPreferences prefs;
  final LibrarySnapshot snapshot;
  final FileStore fileStore;
  final SyncRepository syncRepository;
  final ComplianceRepository complianceRepository;

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
  _FakeSyncRepo({required this.status});

  final SyncStatus status;
  int syncCalls = 0;
  int signInCalls = 0;

  @override
  Future<void> signInGoogleDrive() async {
    signInCalls += 1;
  }

  @override
  Future<void> syncNow() async {
    syncCalls += 1;
  }

  @override
  Stream<SyncStatus> watchSyncStatus() => Stream<SyncStatus>.value(status);
}

class _FakeComplianceRepo implements ComplianceRepository {
  const _FakeComplianceRepo({required this.summary});

  final ComplianceSummary summary;

  @override
  Future<ComplianceSummary> scanNow() async => summary;

  @override
  Stream<ComplianceSummary> watchComplianceSummary() {
    return Stream<ComplianceSummary>.value(summary);
  }
}

class _FakeFileStore implements FileStore {
  _FakeFileStore({required this.status});

  final StorageStatus status;
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
  Future<bool> exists(String relativePath) async => false;

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
  Future<String> readText(String relativePath) async => '';

  @override
  Future<void> writeBytes(String relativePath, List<int> bytes) async {}

  @override
  Future<void> writeText(String relativePath, String contents) async {}
}
