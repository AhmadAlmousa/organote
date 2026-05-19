import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import 'app_providers.dart';

final libraryProvider = StreamProvider<LibrarySnapshot>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchLibrary();
});

final librarySnapshotProvider = Provider<LibrarySnapshot>((ref) {
  return ref
      .watch(libraryProvider)
      .maybeWhen(
        data: (snapshot) => snapshot,
        orElse: () => const LibrarySnapshot(),
      );
});
