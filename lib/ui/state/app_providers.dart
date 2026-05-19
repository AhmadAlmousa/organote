import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../di/service_locator.dart';
import '../../domain/repositories/repositories.dart';
import '../../services/storage/file_store.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

final fileStoreProvider = Provider<FileStore>((ref) => getIt<FileStore>());

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => getIt<LibraryRepository>(),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => getIt<NoteRepository>(),
);

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => getIt<TemplateRepository>(),
);

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => getIt<CategoryRepository>(),
);

final assetRepositoryProvider = Provider<AssetRepository>(
  (ref) => getIt<AssetRepository>(),
);

final complianceRepositoryProvider = Provider<ComplianceRepository>(
  (ref) => getIt<ComplianceRepository>(),
);

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => getIt<SyncRepository>(),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => getIt<BackupRepository>(),
);
