import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'di/service_locator.dart';
import 'services/logging/error_log_service.dart';
import 'services/storage/file_store.dart';
import 'ui/organote_app.dart';
import 'ui/state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvironment();
  await configureDependencies();
  final prefs = await SharedPreferences.getInstance();
  final errorLogService = ErrorLogService(
    fileStore: getIt<FileStore>(),
    preferences: prefs,
  );
  _installErrorLogging(errorLogService);
  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            errorLogServiceProvider.overrideWithValue(errorLogService),
          ],
          child: const OrganoteApp(),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(errorLogService.recordError(error, stackTrace, source: 'zone'));
    },
  );
}

Future<void> _loadEnvironment() async {
  if (kIsWeb) {
    dotenv.loadFromString(isOptional: true);
    return;
  }
  await dotenv.load(fileName: '.env', isOptional: true);
}

void _installErrorLogging(ErrorLogService errorLogService) {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(errorLogService.recordFlutterError(details));
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      errorLogService.recordError(error, stackTrace, source: 'platform'),
    );
    return false;
  };
}
