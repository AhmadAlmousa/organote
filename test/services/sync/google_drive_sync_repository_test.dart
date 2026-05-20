import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/services/storage/memory_file_store.dart';
import 'package:organote/services/sync/google_drive_sync_repository.dart';
import 'package:organote/services/sync/remote_file_provider.dart';
import 'package:organote/services/sync/sync_models.dart';

void main() {
  group('GoogleDriveSyncRepository', () {
    test('uploads local new files and persists sync ledger entries', () async {
      final store = MemoryFileStore();
      await store.initialize();
      await store.writeText('notes/local.md', '# Local\n');
      final remote = _FakeRemoteFileProvider();
      final repository = GoogleDriveSyncRepository(
        fileStore: store,
        remoteFileProvider: remote,
      );

      await repository.syncNow();

      expect(remote.uploadedPaths, ['notes/local.md']);
      final ledger = await _readLedger(store);
      expect(ledger.single['relativePath'], 'notes/local.md');
      expect(ledger.single['remoteFileId'], 'remote-notes/local.md');
    });

    test('downloads remote new files into the local store', () async {
      final store = MemoryFileStore();
      await store.initialize();
      final remote = _FakeRemoteFileProvider()
        ..seed('notes/remote.md', '# Remote\n');
      final repository = GoogleDriveSyncRepository(
        fileStore: store,
        remoteFileProvider: remote,
      );

      await repository.syncNow();

      expect(await store.readText('notes/remote.md'), '# Remote\n');
      final ledger = await _readLedger(store);
      expect(ledger.single['relativePath'], 'notes/remote.md');
      expect(ledger.single['remoteFileId'], 'remote-notes/remote.md');
    });

    test(
      'pushes soft-delete when a tracked file has been deleted locally',
      () async {
        final store = MemoryFileStore();
        await store.initialize();
        final remote = _FakeRemoteFileProvider()
          ..seed('notes/keep.md', '# Keep\n')
          ..seed('notes/bye.md', '# Bye\n');
        final repository = GoogleDriveSyncRepository(
          fileStore: store,
          remoteFileProvider: remote,
        );

        await repository.syncNow();
        // Delete locally — simulates the user soft-deleting and the file
        // being removed by another flow before the next sync.
        await store.delete('notes/bye.md');

        await repository.syncNow();

        expect(remote.softDeletedPaths, ['notes/bye.md']);
        final ledger = await _readLedger(store);
        expect(ledger.map((entry) => entry['relativePath']).toList(), [
          'notes/keep.md',
        ]);
      },
    );

    test('deletes local files when the remote has dropped them', () async {
      final store = MemoryFileStore();
      await store.initialize();
      final remote = _FakeRemoteFileProvider()..seed('notes/bye.md', '# Bye\n');
      final repository = GoogleDriveSyncRepository(
        fileStore: store,
        remoteFileProvider: remote,
      );

      await repository.syncNow();
      expect(await store.exists('notes/bye.md'), isTrue);

      // Remote drops the file outside the sync flow.
      remote.files.remove('notes/bye.md');

      await repository.syncNow();

      expect(await store.exists('notes/bye.md'), isFalse);
      expect(await _readLedger(store), isEmpty);
    });

    test('intercepts zombie remote files referenced by local trash', () async {
      final store = MemoryFileStore();
      await store.initialize();
      await store.writeText(
        '.organote/trash.json',
        jsonEncode([
          {
            'id': 't1',
            'originalPath': 'notes/zombie.md',
            'trashPath': 'trash/notes/zombie.md',
            'deletedAt': DateTime.utc(2026).toIso8601String(),
            'type': 'note',
            'checksum': null,
          },
        ]),
      );
      final remote = _FakeRemoteFileProvider()
        ..seed('notes/zombie.md', '# Zombie\n');
      final repository = GoogleDriveSyncRepository(
        fileStore: store,
        remoteFileProvider: remote,
      );

      await repository.syncNow();

      expect(remote.softDeletedPaths, ['notes/zombie.md']);
      expect(await store.exists('notes/zombie.md'), isFalse);
    });

    test('uses remote clock last-write-wins for concurrent edits', () async {
      final store = MemoryFileStore();
      await store.initialize();
      await store.writeText('notes/conflict.md', '# Local edit\n');
      final remote = _FakeRemoteFileProvider();
      final repository = GoogleDriveSyncRepository(
        fileStore: store,
        remoteFileProvider: remote,
      );

      // First sync: file is treated as local-new, uploads.
      await repository.syncNow();

      // Simulate divergence: local edits again AND remote advances.
      await store.writeText('notes/conflict.md', '# Local edit 2\n');
      remote.bumpToFuture('notes/conflict.md', '# Remote wins\n');

      await repository.syncNow();

      // Remote clock newer -> downloadRemoteConflictWinner.
      expect(await store.readText('notes/conflict.md'), '# Remote wins\n');
    });

    test(
      'sequential lock collapses concurrent syncNow into one execution',
      () async {
        final store = MemoryFileStore();
        await store.initialize();
        await store.writeText('notes/local.md', '# Local\n');
        final remote = _FakeRemoteFileProvider();
        final repository = GoogleDriveSyncRepository(
          fileStore: store,
          remoteFileProvider: remote,
        );

        final first = repository.syncNow();
        final second = repository.syncNow();

        expect(identical(first, second), isTrue);
        await Future.wait([first, second]);
        expect(
          remote.uploadedPaths.where((p) => p == 'notes/local.md').length,
          1,
        );
      },
    );

    test(
      'emits status transitions in order during a successful sync',
      () async {
        final store = MemoryFileStore();
        await store.initialize();
        await store.writeText('notes/local.md', '# Local\n');
        final remote = _FakeRemoteFileProvider();
        final repository = GoogleDriveSyncRepository(
          fileStore: store,
          remoteFileProvider: remote,
        );
        final phases = <SyncPhase>[];
        final subscription = repository.watchSyncStatus().listen(
          (status) => phases.add(status.phase),
        );

        await repository.syncNow();
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(phases.first, SyncPhase.scanning);
        expect(
          phases,
          containsAllInOrder(<SyncPhase>[
            SyncPhase.scanning,
            SyncPhase.syncing,
            SyncPhase.complete,
          ]),
        );
      },
    );

    test('emits error status when sync runs before sign-in', () async {
      final store = MemoryFileStore();
      await store.initialize();
      final repository = GoogleDriveSyncRepository(fileStore: store);
      SyncStatus? latest;
      final subscription = repository.watchSyncStatus().listen(
        (status) => latest = status,
      );

      await repository.syncNow();
      await subscription.cancel();

      expect(latest?.phase, SyncPhase.error);
      expect(latest?.message, contains('not connected'));
    });

    test(
      'explains missing Android web client ID before plugin sign-in',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final store = MemoryFileStore();
        await store.initialize();
        final repository = GoogleDriveSyncRepository(fileStore: store);

        await expectLater(
          repository.signInGoogleDrive(),
          throwsA(
            isA<GoogleSignInException>()
                .having(
                  (error) => error.code,
                  'code',
                  GoogleSignInExceptionCode.clientConfigurationError,
                )
                .having(
                  (error) => error.description,
                  'description',
                  contains('Web OAuth client ID'),
                ),
          ),
        );
      },
    );
  });
}

Future<List<Map<String, dynamic>>> _readLedger(MemoryFileStore store) async {
  final source = await store.readText('.organote/sync_ledger.json');
  return (jsonDecode(source) as List<dynamic>).cast<Map<String, dynamic>>();
}

class _FakeRemoteFileProvider implements RemoteFileProvider {
  final Map<String, List<int>> files = <String, List<int>>{};
  final Map<String, DateTime> modifiedAt = <String, DateTime>{};
  final List<String> uploadedPaths = <String>[];
  final List<String> softDeletedPaths = <String>[];

  void seed(String relativePath, String contents) {
    files[relativePath] = utf8.encode(contents);
    modifiedAt[relativePath] = DateTime.utc(2026);
  }

  void bumpToFuture(String relativePath, String contents) {
    files[relativePath] = utf8.encode(contents);
    modifiedAt[relativePath] = DateTime.utc(2030);
  }

  @override
  Future<List<int>> download(String relativePath) async {
    return files[relativePath]!;
  }

  @override
  Future<Map<String, SyncManifestEntry>> listManifest({
    required Set<String> referencedAssetPaths,
  }) async {
    return files.map((path, bytes) {
      return MapEntry(
        path,
        SyncManifestEntry(
          relativePath: path,
          checksum:
              '$path-${bytes.length}-${modifiedAt[path]!.toIso8601String()}',
          modifiedAt: modifiedAt[path] ?? DateTime.utc(2026),
          remoteFileId: 'remote-$path',
        ),
      );
    });
  }

  @override
  Future<void> pushSoftDelete(
    String relativePath, {
    String? remoteFileId,
  }) async {
    softDeletedPaths.add(relativePath);
    files.remove(relativePath);
    modifiedAt.remove(relativePath);
  }

  @override
  Future<SyncManifestEntry> upload({
    required String relativePath,
    required List<int> bytes,
    String? remoteFileId,
  }) async {
    uploadedPaths.add(relativePath);
    files[relativePath] = bytes;
    modifiedAt[relativePath] = DateTime.utc(2026, 1, 2);
    return SyncManifestEntry(
      relativePath: relativePath,
      checksum: '$relativePath-${bytes.length}',
      modifiedAt: modifiedAt[relativePath]!,
      remoteFileId: remoteFileId ?? 'remote-$relativePath',
    );
  }
}
