import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/services/logging/error_log_service.dart';
import 'package:organote/services/storage/memory_file_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('does not write when error logging is disabled', () async {
    final consoleMessages = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      consoleMessages.add(message ?? '');
    };
    addTearDown(() => debugPrint = originalDebugPrint);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = MemoryFileStore();
    await store.initialize();
    final service = ErrorLogService(fileStore: store, preferences: prefs);

    await service.recordError(
      StateError('boom'),
      StackTrace.current,
      source: 'test',
    );

    expect(await store.exists(ErrorLogService.logPath), isFalse);
    expect(consoleMessages.single, contains('Organote error'));
    expect(consoleMessages.single, contains('source: test'));
  });

  test('writes errors into .organote log when enabled', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ErrorLogService.enabledPreferenceKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = MemoryFileStore();
    await store.initialize();
    final service = ErrorLogService(fileStore: store, preferences: prefs);

    await service.recordError(
      StateError('sync failed'),
      StackTrace.current,
      source: 'settings.connectDrive',
    );

    final log = await store.readText(ErrorLogService.logPath);
    expect(log, contains('source: settings.connectDrive'));
    expect(log, contains('Bad state: sync failed'));
    expect(log, contains('stack:'));
  });
}
