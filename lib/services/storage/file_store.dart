import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const organoteStorageDirectories = <String>[
  'templates',
  'notes',
  'assets',
  'trash',
  '.organote',
];

enum StorageUnavailableReason {
  unsupportedPlatform,
  permissionDenied,
  rootNotSelected,
  notInitialized,
}

class StorageUnavailableException implements Exception {
  const StorageUnavailableException(this.reason, this.message);

  final StorageUnavailableReason reason;
  final String message;

  @override
  String toString() => 'StorageUnavailableException($reason): $message';
}

class StorageStatus {
  const StorageStatus.available({this.rootLabel})
    : isAvailable = true,
      reason = null,
      message = null;

  const StorageStatus.unavailable({
    required this.reason,
    required this.message,
    this.rootLabel,
  }) : isAvailable = false;

  final bool isAvailable;
  final StorageUnavailableReason? reason;
  final String? message;
  final String? rootLabel;
}

class StoredFile {
  const StoredFile({
    required this.relativePath,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String relativePath;
  final int sizeBytes;
  final DateTime modifiedAt;
}

abstract interface class FileStore {
  Future<StorageStatus> getStatus();

  Future<void> initialize({String? rootPath});

  Future<void> chooseRootDirectory();

  Future<void> ensureStructure();

  Future<List<StoredFile>> listFiles(
    String relativeDirectory, {
    bool recursive = false,
  });

  Future<bool> exists(String relativePath);

  Future<String> readText(String relativePath);

  Future<void> writeText(String relativePath, String contents);

  Future<List<int>> readBytes(String relativePath);

  Future<void> writeBytes(String relativePath, List<int> bytes);

  Future<void> createDirectory(String relativePath);

  Future<void> delete(String relativePath, {bool recursive = false});

  Future<void> move(String fromRelativePath, String toRelativePath);
}

String sanitizeFileName(String input, {String fallback = 'untitled'}) {
  final normalized = input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9._ -]+'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  return normalized.isEmpty ? fallback : normalized;
}

String normalizeRelativePath(String path) {
  final normalized = p.posix.normalize(path.replaceAll('\\', '/'));
  if (normalized == '.' || normalized.isEmpty) {
    return '';
  }
  if (p.posix.isAbsolute(normalized) || normalized.startsWith('..')) {
    throw ArgumentError.value(path, 'path', 'Path must stay inside storage');
  }
  return normalized;
}

String checksumBytes(List<int> bytes) {
  return md5.convert(bytes).toString();
}

String checksumText(String text) {
  return checksumBytes(utf8.encode(text));
}
