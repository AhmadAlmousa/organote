import 'package:flutter_test/flutter_test.dart';
import 'package:organote/services/storage/file_store.dart';
import 'package:organote/services/storage/memory_file_store.dart';

void main() {
  group('sanitizeFileName', () {
    test(
      'lowercases, replaces whitespace with dashes, and strips specials',
      () {
        expect(sanitizeFileName('Home Lab'), 'home-lab');
        expect(sanitizeFileName('  Mixed   Case  '), 'mixed-case');
        expect(sanitizeFileName('Rack #1 Photo!'), 'rack-1-photo');
      },
    );

    test('collapses consecutive dashes and trims dashes/dots from edges', () {
      expect(sanitizeFileName('--Lots---Of---Dashes--'), 'lots-of-dashes');
      expect(sanitizeFileName('.dotfile.'), 'dotfile');
    });

    test('preserves dots inside the name for extensions', () {
      expect(sanitizeFileName('Rack Photo.PNG'), 'rack-photo.png');
    });

    test('falls back to default when nothing usable remains', () {
      expect(sanitizeFileName('***'), 'untitled');
      expect(sanitizeFileName('   '), 'untitled');
      expect(sanitizeFileName('!@#', fallback: 'empty'), 'empty');
    });
  });

  group('normalizeRelativePath', () {
    test('returns an empty string for the current directory', () {
      expect(normalizeRelativePath(''), '');
      expect(normalizeRelativePath('.'), '');
      expect(normalizeRelativePath('./'), '');
    });

    test('rewrites back-slashes and collapses redundant segments', () {
      expect(normalizeRelativePath('notes\\infra\\lab'), 'notes/infra/lab');
      expect(
        normalizeRelativePath('notes/./infra/../infra/lab'),
        'notes/infra/lab',
      );
    });

    test('rejects absolute paths and escapes outside the root', () {
      expect(() => normalizeRelativePath('/etc/passwd'), throwsArgumentError);
      expect(() => normalizeRelativePath('../escaped'), throwsArgumentError);
    });
  });

  group('MemoryFileStore', () {
    test(
      'initialize marks the store ready and ensureStructure is idempotent',
      () async {
        final store = MemoryFileStore();

        final beforeStatus = await store.getStatus();
        expect(beforeStatus.isAvailable, isFalse);
        expect(beforeStatus.reason, StorageUnavailableReason.notInitialized);

        await store.initialize();
        await store.ensureStructure();
        await store.ensureStructure();

        final afterStatus = await store.getStatus();
        expect(afterStatus.isAvailable, isTrue);
        expect(afterStatus.rootLabel, 'memory');
      },
    );

    test('throws StorageUnavailableException before initialize', () async {
      final store = MemoryFileStore();
      expect(
        () => store.writeText('notes/foo.md', 'hi'),
        throwsA(isA<StorageUnavailableException>()),
      );
    });

    test(
      'lists files non-recursively without descending into subdirs',
      () async {
        final store = MemoryFileStore();
        await store.initialize();
        await store.writeText('notes/top.md', 'top');
        await store.writeText('notes/infra/lab.md', 'lab');

        final shallow = await store.listFiles('notes');
        expect(shallow.map((file) => file.relativePath), ['notes/top.md']);

        final deep = await store.listFiles('notes', recursive: true);
        expect(
          deep.map((file) => file.relativePath),
          containsAll(<String>['notes/top.md', 'notes/infra/lab.md']),
        );
      },
    );

    test('move relocates a directory subtree to a new prefix', () async {
      final store = MemoryFileStore();
      await store.initialize();
      await store.writeText('notes/infra/a.md', 'a');
      await store.writeText('notes/infra/sub/b.md', 'b');

      await store.move('notes/infra', 'notes/platform');

      expect(await store.exists('notes/infra/a.md'), isFalse);
      expect(await store.exists('notes/platform/a.md'), isTrue);
      expect(await store.exists('notes/platform/sub/b.md'), isTrue);
    });

    test('delete with recursive removes a directory subtree', () async {
      final store = MemoryFileStore();
      await store.initialize();
      await store.writeText('trash/notes/a.md', 'a');
      await store.writeText('trash/notes/b.md', 'b');

      await store.delete('trash/notes', recursive: true);

      expect(await store.exists('trash/notes/a.md'), isFalse);
      expect(await store.exists('trash/notes/b.md'), isFalse);
    });
  });

  group('checksum helpers', () {
    test('checksumText and checksumBytes agree for the same content', () {
      expect(checksumText('hello'), checksumBytes('hello'.codeUnits));
    });

    test('different inputs produce different checksums', () {
      expect(checksumText('a'), isNot(equals(checksumText('b'))));
    });
  });
}
