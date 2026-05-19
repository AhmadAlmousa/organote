import 'sync_models.dart';

abstract interface class RemoteFileProvider {
  Future<Map<String, SyncManifestEntry>> listManifest({
    required Set<String> referencedAssetPaths,
  });

  Future<List<int>> download(String relativePath);

  Future<SyncManifestEntry> upload({
    required String relativePath,
    required List<int> bytes,
    String? remoteFileId,
  });

  Future<void> pushSoftDelete(String relativePath, {String? remoteFileId});
}
