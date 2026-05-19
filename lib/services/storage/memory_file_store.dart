import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import 'file_store.dart';

class MemoryFileStore implements FileStore {
  final Map<String, List<int>> _files = <String, List<int>>{};
  final Map<String, DateTime> _modifiedAt = <String, DateTime>{};
  bool _initialized = false;

  @override
  Future<void> initialize({String? rootPath}) async {
    _initialized = true;
    await ensureStructure();
  }

  @override
  Future<void> chooseRootDirectory() async => initialize();

  @override
  Future<StorageStatus> getStatus() async {
    return _initialized
        ? const StorageStatus.available(rootLabel: 'memory')
        : const StorageStatus.unavailable(
            reason: StorageUnavailableReason.notInitialized,
            message: 'Memory file store has not been initialized.',
          );
  }

  @override
  Future<void> ensureStructure() async {
    _checkReady();
  }

  @override
  Future<void> createDirectory(String relativePath) async {
    _checkReady();
    normalizeRelativePath(relativePath);
  }

  @override
  Future<bool> exists(String relativePath) async {
    _checkReady();
    final path = normalizeRelativePath(relativePath);
    return _files.containsKey(path) ||
        _files.keys.any((candidate) => candidate.startsWith('$path/'));
  }

  @override
  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  }) async {
    _checkReady();
    final directory = normalizeRelativePath(relativeDirectory);
    final prefix = directory.isEmpty ? '' : '$directory/';
    final files = _files.entries
        .where((entry) {
          if (!entry.key.startsWith(prefix)) {
            return false;
          }
          if (recursive) {
            return true;
          }
          final rest = entry.key.substring(prefix.length);
          return !rest.contains('/');
        })
        .map((entry) {
          return StoredFile(
            relativePath: entry.key,
            sizeBytes: entry.value.length,
            modifiedAt:
                _modifiedAt[entry.key] ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .toList();
    files.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return files;
  }

  @override
  Future<String> readText(String relativePath) async {
    return utf8.decode(await readBytes(relativePath));
  }

  @override
  Future<void> writeText(String relativePath, String contents) {
    return writeBytes(relativePath, utf8.encode(contents));
  }

  @override
  Future<List<int>> readBytes(String relativePath) async {
    _checkReady();
    final path = normalizeRelativePath(relativePath);
    final bytes = _files[path];
    if (bytes == null) {
      throw StateError('File not found: $path');
    }
    return List<int>.from(bytes);
  }

  @override
  Future<void> writeBytes(String relativePath, List<int> bytes) async {
    _checkReady();
    final path = normalizeRelativePath(relativePath);
    _files[path] = List<int>.from(bytes);
    _modifiedAt[path] = DateTime.now().toUtc();
  }

  @override
  Future<void> delete(String relativePath, {bool recursive = false}) async {
    _checkReady();
    final path = normalizeRelativePath(relativePath);
    if (_files.remove(path) != null) {
      _modifiedAt.remove(path);
      return;
    }
    if (!recursive) {
      return;
    }
    final prefix = path.isEmpty ? '' : '$path/';
    final keys = _files.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      _files.remove(key);
      _modifiedAt.remove(key);
    }
  }

  @override
  Future<void> move(String fromRelativePath, String toRelativePath) async {
    _checkReady();
    final from = normalizeRelativePath(fromRelativePath);
    final to = normalizeRelativePath(toRelativePath);
    final exact = _files.remove(from);
    if (exact != null) {
      _files[to] = exact;
      _modifiedAt[to] = DateTime.now().toUtc();
      _modifiedAt.remove(from);
      return;
    }
    final prefix = '$from/';
    final moving = _files.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in moving) {
      final suffix = key.substring(prefix.length);
      final next = p.posix.join(to, suffix);
      _files[next] = _files.remove(key)!;
      _modifiedAt[next] = DateTime.now().toUtc();
      _modifiedAt.remove(key);
    }
  }

  bool hasSameBytes(String relativePath, List<int> bytes) {
    final existing = _files[normalizeRelativePath(relativePath)];
    return const ListEquality<int>().equals(existing, bytes);
  }

  void _checkReady() {
    if (!_initialized) {
      throw const StorageUnavailableException(
        StorageUnavailableReason.notInitialized,
        'Memory file store has not been initialized.',
      );
    }
  }
}
