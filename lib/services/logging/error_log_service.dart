import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/file_store.dart';

class ErrorLogService {
  ErrorLogService({
    required FileStore fileStore,
    required SharedPreferences preferences,
  }) : _fileStore = fileStore,
       _preferences = preferences;

  static const enabledPreferenceKey = 'organote.diagnostics.errorLogEnabled';
  static const logPath = '.organote/errors.log';
  static const _maxLogLength = 256 * 1024;

  final FileStore _fileStore;
  final SharedPreferences _preferences;

  bool get isEnabled => _preferences.getBool(enabledPreferenceKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await _preferences.setBool(enabledPreferenceKey, value);
    if (value) {
      await recordMessage('Error logging enabled', source: 'settings');
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    return recordError(
      details.exception,
      details.stack,
      source: details.context?.toStringDeep().trim().isEmpty ?? true
          ? 'flutter'
          : 'flutter: ${details.context}',
      library: details.library,
    );
  }

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required String source,
    String? library,
  }) async {
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln('timestamp: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('source: $source');
    if (library != null && library.trim().isNotEmpty) {
      buffer.writeln('library: $library');
    }
    buffer
      ..writeln('error: $error')
      ..writeln('stack:');
    if (stackTrace == null) {
      buffer.writeln('<none>');
    } else {
      buffer.writeln(stackTrace);
    }
    final entry = buffer.toString();
    _writeErrorToConsole(entry);
    if (!isEnabled) {
      return;
    }
    await _append(entry);
  }

  Future<void> recordMessage(String message, {required String source}) async {
    if (!isEnabled) {
      return;
    }
    final entry = StringBuffer()
      ..writeln('---')
      ..writeln('timestamp: ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln('source: $source')
      ..writeln('message: $message');
    await _append(entry.toString());
  }

  Future<void> _append(String entry) async {
    try {
      await _fileStore.ensureStructure();
      final existing = await _fileStore.exists(logPath)
          ? await _fileStore.readText(logPath)
          : '';
      final next = _trimLog('$existing$entry\n');
      await _fileStore.writeText(logPath, next);
    } catch (_) {
      // Logging must never become the app error.
    }
  }

  String _trimLog(String contents) {
    if (contents.length <= _maxLogLength) {
      return contents;
    }
    return contents.substring(contents.length - _maxLogLength);
  }

  void _writeErrorToConsole(String entry) {
    debugPrint('Organote error\n$entry');
  }
}
