import 'package:get_it/get_it.dart';

import '../data/markdown/markdown_codec.dart';
import '../data/repositories/local_organote_repository.dart';
import '../domain/repositories/repositories.dart';
import '../services/compliance/compliance_service.dart';
import '../services/storage/file_store.dart';
import '../services/storage/file_store_factory.dart';
import '../services/sync/google_drive_sync_repository.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({FileStore? fileStore}) async {
  if (getIt.isRegistered<FileStore>()) {
    return;
  }

  final store = fileStore ?? createPlatformFileStore();
  try {
    await store.initialize();
  } on StorageUnavailableException {
    // Web intentionally remains unavailable until a user gesture chooses a
    // directory. Native platforms initialize a default app documents folder.
  }

  final syncRepository = GoogleDriveSyncRepository(fileStore: store);
  final localRepository = LocalOrganoteRepository(
    fileStore: store,
    markdownCodec: const MarkdownCodec(),
    complianceService: const ComplianceService(),
    syncRepository: syncRepository,
  );

  getIt
    ..registerSingleton<FileStore>(store)
    ..registerSingleton<SyncRepository>(syncRepository)
    ..registerSingleton<LibraryRepository>(localRepository)
    ..registerSingleton<NoteRepository>(localRepository)
    ..registerSingleton<TemplateRepository>(localRepository)
    ..registerSingleton<CategoryRepository>(localRepository)
    ..registerSingleton<AssetRepository>(localRepository)
    ..registerSingleton<ComplianceRepository>(localRepository)
    ..registerSingleton<BackupRepository>(localRepository);

  try {
    await localRepository.reload();
  } on StorageUnavailableException {
    // The app shell will surface storage status and allow setup.
  }
}
