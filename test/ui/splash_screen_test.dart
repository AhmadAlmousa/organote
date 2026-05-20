import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
import 'package:organote/services/storage/file_store.dart';
import 'package:organote/ui/app/splash_screen.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';

void main() {
  testWidgets('SplashScreen blocks unsupported web folder access clearly', (
    tester,
  ) async {
    final store = _FakeFileStore(
      status: const StorageStatus.unavailable(
        reason: StorageUnavailableReason.unsupportedPlatform,
        message:
            'Mobile browsers do not expose folder access. Use desktop Chrome or Edge.',
      ),
    );

    await tester.pumpWidget(_Harness(fileStore: store));
    await tester.pump();

    expect(find.text('Desktop browser required'), findsOneWidget);
    expect(find.text('Folder picker unavailable'), findsOneWidget);
    expect(
      find.textContaining('Mobile browsers do not expose'),
      findsOneWidget,
    );

    await tester.tap(
      find.text('Folder picker unavailable'),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(store.chooseCount, isZero);
  });

  testWidgets('SplashScreen surfaces storage picker failures', (tester) async {
    final store = _FakeFileStore(
      status: const StorageStatus.unavailable(
        reason: StorageUnavailableReason.rootNotSelected,
        message: 'Choose a real storage folder before using Organote.',
      ),
      chooseError: const StorageUnavailableException(
        StorageUnavailableReason.permissionDenied,
        'Folder permission was denied.',
      ),
    );

    await tester.pumpWidget(_Harness(fileStore: store));
    await tester.pump();

    await tester.tap(find.text('Choose folder'));
    await tester.pump();

    expect(store.chooseCount, 1);
    expect(find.text('Folder permission was denied.'), findsOneWidget);
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.fileStore});

  final FileStore fileStore;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );
    return ProviderScope(
      overrides: [
        fileStoreProvider.overrideWithValue(fileStore),
        libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepository()),
      ],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: SplashScreen(onReady: () {}),
        ),
      ),
    );
  }
}

class _FakeLibraryRepository implements LibraryRepository {
  @override
  Future<LibrarySnapshot> reload() async => const LibrarySnapshot();

  @override
  Stream<LibrarySnapshot> watchLibrary() =>
      Stream<LibrarySnapshot>.value(const LibrarySnapshot());
}

class _FakeFileStore implements FileStore {
  _FakeFileStore({required this.status, this.chooseError});

  final StorageStatus status;
  final Object? chooseError;
  int chooseCount = 0;

  @override
  Future<StorageStatus> getStatus() async => status;

  @override
  Future<void> chooseRootDirectory() async {
    chooseCount += 1;
    final error = chooseError;
    if (error != null) throw error;
  }

  @override
  Future<void> createDirectory(String relativePath) async {}

  @override
  Future<void> delete(String relativePath, {bool recursive = false}) async {}

  @override
  Future<bool> exists(String relativePath) async => false;

  @override
  Future<void> ensureStructure() async {}

  @override
  Future<void> initialize({String? rootPath}) async {}

  @override
  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  }) async => const <StoredFile>[];

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
