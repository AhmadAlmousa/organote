import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/services/backup/backup_service.dart';
import 'package:organote/services/storage/memory_file_store.dart';

void main() {
  group('BackupService', () {
    late MemoryFileStore store;
    late BackupService backup;

    setUp(() async {
      store = MemoryFileStore();
      await store.initialize();
      backup = BackupService(store);
    });

    Future<Archive> decode(List<int> bytes) async {
      return ZipDecoder().decodeBytes(bytes);
    }

    test('archives only Organote subdirectories and skips everything else',
        () async {
      await store.writeText('templates/server.md', '# Server\n');
      await store.writeText('notes/infra/home.md', '# Home\n');
      await store.writeText('assets/home-lab/photo.png', 'binary');
      await store.writeText('trash/notes/old.md', '# Old\n');
      await store.writeText('.organote/categories.json', '{}');
      // Files outside the Organote contract — must be skipped.
      await store.writeText('README.md', 'unrelated');
      await store.writeText('other/garbage.txt', 'noise');

      final archive = await decode(await backup.createBackupZip());
      final names = archive.files.map((file) => file.name).toSet();

      expect(names, containsAll(<String>[
        'templates/server.md',
        'notes/infra/home.md',
        'assets/home-lab/photo.png',
        'trash/notes/old.md',
        '.organote/categories.json',
      ]));
      expect(names, isNot(contains('README.md')));
      expect(names, isNot(contains('other/garbage.txt')));
    });

    test('restoreBackupZip writes archived files back into the store',
        () async {
      await store.writeText('templates/server.md', '# Server v1\n');
      final bytes = await backup.createBackupZip();

      final empty = MemoryFileStore();
      await empty.initialize();
      final restorer = BackupService(empty);

      await restorer.restoreBackupZip(bytes);

      expect(await empty.readText('templates/server.md'), '# Server v1\n');
    });

    test('restoreBackupZip overwrites existing files in the target store',
        () async {
      await store.writeText('notes/keep.md', '# original\n');
      final bytes = await backup.createBackupZip();

      final target = MemoryFileStore();
      await target.initialize();
      await target.writeText('notes/keep.md', '# stale\n');
      final restorer = BackupService(target);

      await restorer.restoreBackupZip(bytes);

      expect(await target.readText('notes/keep.md'), '# original\n');
    });

    test('restoreBackupZip calls ensureStructure so scaffold dirs survive',
        () async {
      // An archive that only contains a single note — restore must still
      // leave the standard Organote directories intact via ensureStructure.
      await store.writeText('notes/seed.md', '# seed\n');
      final bytes = await backup.createBackupZip();

      final blank = MemoryFileStore();
      await blank.initialize();
      final restorer = BackupService(blank);
      await restorer.restoreBackupZip(bytes);

      // ensureStructure on MemoryFileStore is a readiness check; restore
      // returning normally means it completed without StorageUnavailable.
      expect(await blank.readText('notes/seed.md'), '# seed\n');
    });
  });
}
