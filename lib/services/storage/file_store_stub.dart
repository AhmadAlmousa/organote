import 'file_store.dart';

FileStore createFileStore() => UnsupportedFileStore();

class UnsupportedFileStore implements FileStore {
  const UnsupportedFileStore();

  StorageUnavailableException get _exception =>
      const StorageUnavailableException(
        StorageUnavailableReason.unsupportedPlatform,
        'This platform does not expose a supported file backend.',
      );

  @override
  Future<void> chooseRootDirectory() async => throw _exception;

  @override
  Future<void> createDirectory(String relativePath) async => throw _exception;

  @override
  Future<void> delete(String relativePath, {bool recursive = false}) async =>
      throw _exception;

  @override
  Future<bool> exists(String relativePath) async => throw _exception;

  @override
  Future<StorageStatus> getStatus() async {
    return const StorageStatus.unavailable(
      reason: StorageUnavailableReason.unsupportedPlatform,
      message: 'This platform does not expose a supported file backend.',
    );
  }

  @override
  Future<void> initialize({String? rootPath}) async => throw _exception;

  @override
  Future<void> ensureStructure() async => throw _exception;

  @override
  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  }) async => throw _exception;

  @override
  Future<List<int>> readBytes(String relativePath) async => throw _exception;

  @override
  Future<String> readText(String relativePath) async => throw _exception;

  @override
  Future<void> move(String fromRelativePath, String toRelativePath) async =>
      throw _exception;

  @override
  Future<void> writeBytes(String relativePath, List<int> bytes) async =>
      throw _exception;

  @override
  Future<void> writeText(String relativePath, String contents) async =>
      throw _exception;
}
