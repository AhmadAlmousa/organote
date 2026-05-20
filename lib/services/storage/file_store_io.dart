import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_store.dart';

const _rootPreferenceKey = 'organote.storage.root';
const _rootSelectedPreferenceKey = 'organote.storage.root.userSelected';

FileStore createFileStore() => NativeFileStore();

class NativeFileStore implements FileStore {
  Directory? _root;
  String? _rootLabel;
  StorageStatus? _unavailableStatus;

  Directory get _readyRoot {
    final root = _root;
    if (root == null) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.notInitialized,
        'Storage has not been initialized.',
      );
    }
    return root;
  }

  @override
  Future<void> initialize({String? rootPath}) async {
    final prefs = await SharedPreferences.getInstance();
    final documents = await getApplicationDocumentsDirectory();
    final legacyDefaultPath = p.join(documents.path, 'Organote');
    final persistedPath = prefs.getString(_rootPreferenceKey);
    final configuredPath = rootPath ?? persistedPath;
    final wasUserSelected = prefs.getBool(_rootSelectedPreferenceKey) ?? false;
    final hasExplicitPath = rootPath != null && rootPath.trim().isNotEmpty;

    if (configuredPath == null ||
        configuredPath.trim().isEmpty ||
        (!hasExplicitPath &&
            !wasUserSelected &&
            p.equals(
              p.normalize(configuredPath),
              p.normalize(legacyDefaultPath),
            ))) {
      _root = null;
      _rootLabel = null;
      _unavailableStatus = const StorageStatus.unavailable(
        reason: StorageUnavailableReason.rootNotSelected,
        message: 'Choose a storage folder before using Organote.',
      );
      throw const StorageUnavailableException(
        StorageUnavailableReason.rootNotSelected,
        'Choose a storage folder before using Organote.',
      );
    }

    _root = Directory(configuredPath);
    _rootLabel = '${p.basename(_root!.path)} (${_root!.path})';
    _unavailableStatus = null;
    await _readyRoot.create(recursive: true);
    await prefs.setString(_rootPreferenceKey, _readyRoot.path);
    await prefs.setBool(_rootSelectedPreferenceKey, true);
    await ensureStructure();
  }

  @override
  Future<void> chooseRootDirectory() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose Organote storage folder',
    );
    if (selected == null) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.rootNotSelected,
        'No storage directory was selected.',
      );
    }
    await initialize(rootPath: selected);
  }

  @override
  Future<StorageStatus> getStatus() async {
    final root = _root;
    if (root == null) {
      return _unavailableStatus ??
          const StorageStatus.unavailable(
            reason: StorageUnavailableReason.notInitialized,
            message: 'Storage has not been initialized.',
          );
    }
    return StorageStatus.available(rootLabel: _rootLabel ?? root.path);
  }

  @override
  Future<void> ensureStructure() async {
    for (final directory in organoteStorageDirectories) {
      await createDirectory(directory);
    }
  }

  @override
  Future<void> createDirectory(String relativePath) async {
    final directory = Directory(_absolutePath(relativePath));
    await directory.create(recursive: true);
  }

  @override
  Future<bool> exists(String relativePath) {
    return FileSystemEntity.type(
      _absolutePath(relativePath),
    ).then((type) => type != FileSystemEntityType.notFound);
  }

  @override
  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  }) async {
    final directory = Directory(_absolutePath(relativeDirectory));
    if (!await directory.exists()) {
      return const <StoredFile>[];
    }
    final files = <StoredFile>[];
    await for (final entity in directory.list(recursive: recursive)) {
      if (entity is! File) {
        continue;
      }
      final stat = await entity.stat();
      files.add(
        StoredFile(
          relativePath: _relativePath(entity.path),
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }
    files.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return files;
  }

  @override
  Future<String> readText(String relativePath) {
    return File(_absolutePath(relativePath)).readAsString();
  }

  @override
  Future<void> writeText(String relativePath, String contents) async {
    await writeBytes(relativePath, utf8.encode(contents));
  }

  @override
  Future<List<int>> readBytes(String relativePath) {
    return File(_absolutePath(relativePath)).readAsBytes();
  }

  @override
  Future<void> writeBytes(String relativePath, List<int> bytes) async {
    final file = File(_absolutePath(relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String relativePath, {bool recursive = false}) async {
    final path = _absolutePath(relativePath);
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: recursive);
      return;
    }
    await File(path).delete();
  }

  @override
  Future<void> move(String fromRelativePath, String toRelativePath) async {
    final from = _absolutePath(fromRelativePath);
    final to = _absolutePath(toRelativePath);
    final type = await FileSystemEntity.type(from);
    if (type == FileSystemEntityType.notFound) {
      return;
    }
    await Directory(p.dirname(to)).create(recursive: true);
    if (type == FileSystemEntityType.directory) {
      await Directory(from).rename(to);
      return;
    }
    await File(from).rename(to);
  }

  String _absolutePath(String relativePath) {
    final relative = normalizeRelativePath(relativePath);
    final rootPath = _readyRoot.path;
    final absolute = p.normalize(p.join(rootPath, p.fromUri(relative)));
    if (!p.isWithin(rootPath, absolute) && absolute != rootPath) {
      throw ArgumentError.value(relativePath, 'relativePath');
    }
    return absolute;
  }

  String _relativePath(String absolutePath) {
    return p
        .relative(absolutePath, from: _readyRoot.path)
        .replaceAll(p.separator, '/');
  }
}
