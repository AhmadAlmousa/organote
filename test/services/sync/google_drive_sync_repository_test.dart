import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      final ledger =
          jsonDecode(await store.readText('.organote/sync_ledger.json'))
              as List<dynamic>;
      expect(ledger.single['relativePath'], 'notes/local.md');
      expect(ledger.single['remoteFileId'], 'remote-notes/local.md');
    });
  });
}

class _FakeRemoteFileProvider implements RemoteFileProvider {
  final Map<String, List<int>> files = <String, List<int>>{};
  final List<String> uploadedPaths = <String>[];

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
          checksum: '$path-${bytes.length}',
          modifiedAt: DateTime.utc(2026),
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
    files.remove(relativePath);
  }

  @override
  Future<SyncManifestEntry> upload({
    required String relativePath,
    required List<int> bytes,
    String? remoteFileId,
  }) async {
    uploadedPaths.add(relativePath);
    files[relativePath] = bytes;
    return SyncManifestEntry(
      relativePath: relativePath,
      checksum: '$relativePath-${bytes.length}',
      modifiedAt: DateTime.utc(2026, 1, 2),
      remoteFileId: remoteFileId ?? 'remote-$relativePath',
    );
  }
}
