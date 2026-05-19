import 'dart:js_interop';

import 'file_store.dart';

@JS('organoteFs')
external _OrganoteFs get _organoteFs;

extension type _OrganoteFs(JSObject _) implements JSObject {
  external bool isSupported();
  external String rootName();
  external JSPromise<JSString> chooseRoot();
  external JSPromise<JSAny?> ensureStructure(JSArray<JSString> directories);
  external JSPromise<JSArray<JSObject>> listFiles(
    String relativeDirectory,
    bool recursive,
  );
  external JSPromise<JSBoolean> exists(String relativePath);
  external JSPromise<JSString> readText(String relativePath);
  external JSPromise<JSArray<JSNumber>> readBytes(String relativePath);
  external JSPromise<JSAny?> writeText(String relativePath, String contents);
  external JSPromise<JSAny?> writeBytes(
    String relativePath,
    JSArray<JSNumber> bytes,
  );
  external JSPromise<JSAny?> createDirectory(String relativePath);
  external JSPromise<JSAny?> deleteEntry(String relativePath, bool recursive);
  external JSPromise<JSAny?> move(
    String fromRelativePath,
    String toRelativePath,
  );
}

FileStore createFileStore() => WebFileSystemAccessStore();

class WebFileSystemAccessStore implements FileStore {
  bool _initialized = false;

  @override
  Future<void> initialize({String? rootPath}) async {
    if (!_organoteFs.isSupported()) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.unsupportedPlatform,
        'This browser does not support real folder access for Organote.',
      );
    }
    if (_organoteFs.rootName().isEmpty) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.rootNotSelected,
        'Choose a storage folder from a direct user gesture.',
      );
    }
    _initialized = true;
    await ensureStructure();
  }

  @override
  Future<void> chooseRootDirectory() async {
    if (!_organoteFs.isSupported()) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.unsupportedPlatform,
        'This browser does not support the File System Access API.',
      );
    }
    await _organoteFs.chooseRoot().toDart;
    _initialized = true;
    await ensureStructure();
  }

  @override
  Future<StorageStatus> getStatus() async {
    if (!_organoteFs.isSupported()) {
      return const StorageStatus.unavailable(
        reason: StorageUnavailableReason.unsupportedPlatform,
        message: 'Use a secure Chromium-based browser with folder access.',
      );
    }
    final rootName = _organoteFs.rootName();
    if (rootName.isEmpty || !_initialized) {
      return const StorageStatus.unavailable(
        reason: StorageUnavailableReason.rootNotSelected,
        message: 'Choose a real storage folder before using Organote.',
      );
    }
    return StorageStatus.available(rootLabel: '$rootName (chosen folder)');
  }

  @override
  Future<void> ensureStructure() async {
    _checkReady();
    await _organoteFs
        .ensureStructure(
          organoteStorageDirectories.map((dir) => dir.toJS).toList().toJS,
        )
        .toDart;
  }

  @override
  Future<void> createDirectory(String relativePath) async {
    _checkReady();
    await _organoteFs
        .createDirectory(normalizeRelativePath(relativePath))
        .toDart;
  }

  @override
  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  }) async {
    _checkReady();
    final result = await _organoteFs
        .listFiles(normalizeRelativePath(relativeDirectory), recursive)
        .toDart;
    return result.toDart.map((object) {
      final json = object.dartify()! as Map<Object?, Object?>;
      return StoredFile(
        relativePath: json['relativePath']! as String,
        sizeBytes: (json['sizeBytes']! as num).toInt(),
        modifiedAt: DateTime.parse(json['modifiedAt']! as String),
      );
    }).toList();
  }

  @override
  Future<bool> exists(String relativePath) async {
    _checkReady();
    final exists = await _organoteFs
        .exists(normalizeRelativePath(relativePath))
        .toDart;
    return exists.toDart;
  }

  @override
  Future<String> readText(String relativePath) async {
    _checkReady();
    final text = await _organoteFs
        .readText(normalizeRelativePath(relativePath))
        .toDart;
    return text.toDart;
  }

  @override
  Future<void> writeText(String relativePath, String contents) async {
    _checkReady();
    await _organoteFs
        .writeText(normalizeRelativePath(relativePath), contents)
        .toDart;
  }

  @override
  Future<List<int>> readBytes(String relativePath) async {
    _checkReady();
    final bytes = await _organoteFs
        .readBytes(normalizeRelativePath(relativePath))
        .toDart;
    return bytes.toDart.map((number) => number.toDartInt).toList();
  }

  @override
  Future<void> writeBytes(String relativePath, List<int> bytes) async {
    _checkReady();
    await _organoteFs
        .writeBytes(
          normalizeRelativePath(relativePath),
          bytes.map((byte) => byte.toJS).toList().toJS,
        )
        .toDart;
  }

  @override
  Future<void> delete(String relativePath, {bool recursive = false}) async {
    _checkReady();
    await _organoteFs
        .deleteEntry(normalizeRelativePath(relativePath), recursive)
        .toDart;
  }

  @override
  Future<void> move(String fromRelativePath, String toRelativePath) async {
    _checkReady();
    await _organoteFs
        .move(
          normalizeRelativePath(fromRelativePath),
          normalizeRelativePath(toRelativePath),
        )
        .toDart;
  }

  void _checkReady() {
    if (!_initialized) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.rootNotSelected,
        'Choose a storage folder from a direct user gesture.',
      );
    }
  }
}
