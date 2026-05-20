import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:organote/data/repositories/local_organote_repository.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
import 'package:organote/services/storage/memory_file_store.dart';

void main() {
  group('LocalOrganoteRepository', () {
    late MemoryFileStore store;
    late LocalOrganoteRepository repository;

    setUp(() async {
      store = MemoryFileStore();
      await store.initialize();
      repository = LocalOrganoteRepository(fileStore: store);
    });

    test(
      'saves templates and notes as markdown files and emits a snapshot',
      () async {
        final template = await repository.saveTemplate(
          const TemplateInput(
            id: 'server',
            name: 'Server',
            fields: [
              TemplateField(
                id: 'name',
                label: 'Name',
                type: TemplateFieldType.text,
                isRequired: true,
              ),
            ],
          ),
        );

        final note = await repository.saveStructuredNote(
          NoteInput(
            title: 'Home Lab',
            templateId: template.id,
            templateName: template.name,
            templateVersion: template.version,
            categoryPath: 'infra',
            records: const [
              NoteRecord(label: 'Server-1', values: {'Name': 'NAS'}),
            ],
          ),
        );
        final snapshot = await repository.reload();

        expect(template.sourcePath, 'templates/server.md');
        expect(note.sourcePath, 'notes/infra/home-lab.md');
        expect(snapshot.templates.single.id, 'server');
        expect(snapshot.notes.single.title, 'Home Lab');
        expect(snapshot.categories.single.path, 'infra');
      },
    );

    test('imports note images under sanitized note asset folder', () async {
      final note = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Home Lab',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );

      final asset = await repository.importImageForNote(
        noteId: note.id,
        originalName: 'Rack Photo.PNG',
        bytes: [1, 2, 3],
        mediaType: 'image/png',
      );

      expect(asset.relativePath, startsWith('assets/home-lab/'));
      expect(asset.relativePath, endsWith('rack-photo.png'));
      expect(store.hasSameBytes(asset.relativePath, [1, 2, 3]), isTrue);
      expect(await repository.readAssetBytes(asset.relativePath), [1, 2, 3]);
      expect(
        () => repository.readAssetBytes('notes/not-an-asset.md'),
        throwsArgumentError,
      );
    });

    test(
      'reads raw source and toggles pin/favorite without caller rebuilding input',
      () async {
        final note = await repository.saveStructuredNote(
          const NoteInput(
            title: 'Toggle Me',
            records: [
              NoteRecord(label: 'Record', values: {'field': 'value'}),
            ],
          ),
        );

        expect(await repository.getRawSource(note.id), contains('# Toggle Me'));

        await repository.setPinned(note.id, true);
        await repository.setFavorite(note.id, true);
        final updated = await repository.getNote(note.id);

        expect(updated?.isPinned, isTrue);
        expect(updated?.isFavorite, isTrue);
      },
    );

    test('soft deletes notes into trash and writes trash index', () async {
      final note = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Secret',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );

      await repository.softDeleteNote(note.id);
      final snapshot = await repository.reload();
      final trashJson =
          jsonDecode(await store.readText('.organote/trash.json'))
              as List<dynamic>;

      expect(snapshot.notes, isEmpty);
      expect(snapshot.trash.single.originalPath, 'notes/secret.md');
      expect(trashJson.single['originalPath'], 'notes/secret.md');
      expect(trashJson.single['trashPath'], startsWith('trash/notes/'));
    });

    test('creates and restores backup zip bytes', () async {
      await repository.saveStructuredNote(
        const NoteInput(
          title: 'Backup Me',
          records: [
            NoteRecord(label: 'Record', values: {'field': 'value'}),
          ],
        ),
      );

      final backup = await repository.createBackupZip();
      final nextStore = MemoryFileStore();
      await nextStore.initialize();
      final nextRepository = LocalOrganoteRepository(fileStore: nextStore);
      await nextRepository.restoreBackupZip(backup);
      final restored = await nextRepository.reload();

      expect(restored.notes.single.title, 'Backup Me');
    });

    test('appends collision suffixes for duplicate note titles', () async {
      final first = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Duplicate Title',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );
      final second = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Duplicate Title',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );
      final third = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Duplicate Title',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );

      expect(first.sourcePath, 'notes/duplicate-title.md');
      expect(second.sourcePath, 'notes/duplicate-title-2.md');
      expect(third.sourcePath, 'notes/duplicate-title-3.md');
      expect(first.id, isNot(equals(second.id)));
    });

    test('appends collision suffixes for duplicate template names', () async {
      final first = await repository.saveTemplate(
        const TemplateInput(
          id: 'server-a',
          name: 'Server',
          fields: [
            TemplateField(
              id: 'name',
              label: 'Name',
              type: TemplateFieldType.text,
            ),
          ],
        ),
      );
      final second = await repository.saveTemplate(
        const TemplateInput(
          id: 'server-b',
          name: 'Server',
          fields: [
            TemplateField(
              id: 'name',
              label: 'Name',
              type: TemplateFieldType.text,
            ),
          ],
        ),
      );

      expect(first.sourcePath, 'templates/server.md');
      expect(second.sourcePath, 'templates/server-2.md');
    });

    test(
      'keeps the existing note path when re-saving with the same id',
      () async {
        final original = await repository.saveStructuredNote(
          const NoteInput(
            id: 'note-1',
            title: 'Edit Target',
            records: [NoteRecord(label: 'Record', values: {})],
          ),
        );
        final resaved = await repository.saveStructuredNote(
          NoteInput(
            id: original.id,
            title: 'Edit Target',
            records: const [
              NoteRecord(label: 'Record', values: {'field': 'value'}),
            ],
          ),
        );

        expect(resaved.sourcePath, original.sourcePath);
      },
    );

    test('moves notes and color metadata when a category is renamed', () async {
      await repository.saveCategory(
        const Category(
          path: 'infra/lab',
          name: 'lab',
          parentPath: 'infra',
          colorHex: '#abcdef',
        ),
      );
      final note = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Inside Lab',
          categoryPath: 'infra/lab',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );

      await repository.moveCategory('infra/lab', 'platform/lab');
      final snapshot = await repository.reload();

      expect(await store.exists(note.sourcePath!), isFalse);
      expect(await store.exists('notes/platform/lab/inside-lab.md'), isTrue);
      final moved = snapshot.categories.firstWhere(
        (category) => category.path == 'platform/lab',
      );
      expect(moved.colorHex, '#abcdef');
    });

    test('soft deletes a category into trash and clears its color', () async {
      await repository.saveCategory(
        const Category(path: 'infra', name: 'infra', colorHex: '#112233'),
      );
      await repository.saveStructuredNote(
        const NoteInput(
          title: 'In Category',
          categoryPath: 'infra',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );

      await repository.deleteCategory('infra');
      final snapshot = await repository.reload();

      expect(snapshot.notes, isEmpty);
      expect(
        snapshot.categories.where((category) => category.path == 'infra'),
        isEmpty,
      );
      expect(snapshot.trash.single.type, TrashEntryType.category);
      expect(snapshot.trash.single.originalPath, 'notes/infra');
    });

    test('restores a soft-deleted note back to its original path', () async {
      final note = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Restore Me',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );
      final originalPath = note.sourcePath!;

      await repository.softDeleteNote(note.id);
      final afterDelete = await repository.reload();
      expect(afterDelete.notes, isEmpty);
      expect(await store.exists(originalPath), isFalse);

      final trashEntry = afterDelete.trash.single;
      await repository.restoreFromTrash(trashEntry.id);
      final afterRestore = await repository.reload();

      expect(await store.exists(originalPath), isTrue);
      expect(afterRestore.notes.single.id, note.id);
      expect(afterRestore.trash, isEmpty);
    });

    test('purges a trash entry and removes it from the trash index', () async {
      final note = await repository.saveStructuredNote(
        const NoteInput(
          title: 'Purge Me',
          records: [NoteRecord(label: 'Record', values: {})],
        ),
      );

      await repository.softDeleteNote(note.id);
      final afterDelete = await repository.reload();
      final trashEntry = afterDelete.trash.single;
      expect(await store.exists(trashEntry.trashPath), isTrue);

      await repository.purgeTrashEntry(trashEntry.id);
      final afterPurge = await repository.reload();

      expect(await store.exists(trashEntry.trashPath), isFalse);
      expect(afterPurge.trash, isEmpty);
      final trashJson =
          jsonDecode(await store.readText('.organote/trash.json'))
              as List<dynamic>;
      expect(trashJson, isEmpty);
    });

    test(
      'ignores unknown trash ids without throwing on restore or purge',
      () async {
        await repository.restoreFromTrash('does-not-exist');
        await repository.purgeTrashEntry('does-not-exist');

        final snapshot = await repository.reload();
        expect(snapshot.trash, isEmpty);
      },
    );

    test(
      'parses malformed markdown files without crashing the snapshot',
      () async {
        await store.writeText(
          'notes/broken.md',
          'this file has no headings, no metadata, just words.\n',
        );

        final snapshot = await repository.reload();

        expect(snapshot.notes.single.title, 'Untitled');
        expect(snapshot.notes.single.id, 'broken');
        expect(snapshot.notes.single.records, isEmpty);
      },
    );

    test(
      'reads a malformed note title as Untitled but keeps it editable',
      () async {
        await store.writeText('notes/keep.md', '## Stray Record\n');

        final snapshot = await repository.reload();
        final loaded = snapshot.notes.single;
        expect(loaded.title, 'Untitled');
        expect(loaded.records, hasLength(1));
        expect(loaded.records.single.label, 'Stray Record');

        final raw = await repository.getRawSource(loaded.id);
        expect(raw, contains('Stray Record'));
      },
    );

    test(
      'persists ignored compliance issues across reloads and restores them',
      () async {
        final template = await repository.saveTemplate(
          const TemplateInput(
            id: 'server',
            name: 'Server',
            version: 2,
            fields: [
              TemplateField(
                id: 'host',
                label: 'Host',
                type: TemplateFieldType.text,
              ),
            ],
          ),
        );
        await repository.saveStructuredNote(
          NoteInput(
            title: 'Old Note',
            templateId: template.id,
            templateName: template.name,
            templateVersion: 1,
            records: const [
              NoteRecord(label: 'Record', values: {'Host': 'nas-1'}),
            ],
          ),
        );

        final initial = await repository.scanNow();
        final drift = initial.issues.singleWhere(
          (issue) => issue.type == ComplianceIssueType.versionDrift,
        );
        expect(drift.ignored, isFalse);
        expect(initial.activeCount, 1);

        await repository.ignoreIssue(drift.id);

        final afterIgnore = await repository.scanNow();
        final ignoredIssue = afterIgnore.issues.singleWhere(
          (issue) => issue.id == drift.id,
        );
        expect(ignoredIssue.ignored, isTrue);
        expect(afterIgnore.activeCount, isZero);

        final persisted =
            jsonDecode(
                  await store.readText('.organote/compliance_ignores.json'),
                )
                as List<dynamic>;
        expect(persisted, contains(drift.id));

        // Fresh repository instance must still see the persisted ignore.
        final reopened = LocalOrganoteRepository(fileStore: store);
        final reopenedSummary = await reopened.scanNow();
        expect(
          reopenedSummary.issues
              .singleWhere((issue) => issue.id == drift.id)
              .ignored,
          isTrue,
        );
        await reopened.dispose();

        await repository.restoreIgnoredIssue(drift.id);
        final restored = await repository.scanNow();
        final restoredIssue = restored.issues.singleWhere(
          (issue) => issue.id == drift.id,
        );
        expect(restoredIssue.ignored, isFalse);
        expect(restored.activeCount, 1);
      },
    );

    test('ignoreIssue is idempotent for unknown ids', () async {
      await repository.reload();
      await repository.ignoreIssue('does-not-exist');
      await repository.restoreIgnoredIssue('also-missing');
      final summary = await repository.scanNow();
      expect(summary.issues, isEmpty);
    });

    test(
      'reload on an empty store emits an empty snapshot with scaffolded dirs',
      () async {
        final snapshot = await repository.reload();

        expect(snapshot.notes, isEmpty);
        expect(snapshot.templates, isEmpty);
        expect(snapshot.categories, isEmpty);
        expect(snapshot.trash, isEmpty);
        expect(snapshot.tags, isEmpty);
        expect(snapshot.complianceSummary.issues, isEmpty);
        expect(snapshot.complianceSummary.activeCount, 0);
      },
    );

    test(
      'round trips multi-record notes through markdown without losing rows',
      () async {
        final template = await repository.saveTemplate(
          const TemplateInput(
            id: 'family-booklet',
            name: 'Family Booklet',
            fields: [
              TemplateField(
                id: 'name',
                label: 'Name',
                type: TemplateFieldType.text,
                isRequired: true,
              ),
              TemplateField(
                id: 'national-id',
                label: 'ID',
                type: TemplateFieldType.number,
              ),
              TemplateField(
                id: 'dob',
                label: 'DOB',
                type: TemplateFieldType.date,
                calendarMode: CalendarMode.dual,
                primaryCalendar: CalendarSystem.hijri,
              ),
            ],
          ),
        );

        final saved = await repository.saveStructuredNote(
          NoteInput(
            title: 'Smith Family',
            templateId: template.id,
            templateName: template.name,
            templateVersion: template.version,
            categoryPath: 'household/identity',
            records: const [
              NoteRecord(
                label: 'Person-1',
                values: {
                  'Name': 'Ahmad',
                  'ID': '1020304050',
                  'DOB': '01-01-2000 | 24-09-1420 H',
                },
              ),
              NoteRecord(
                label: 'Person-2',
                values: {
                  'Name': 'Sarah',
                  'ID': '2030405060',
                  'DOB': '01-01-2000 | 24-09-1420 H',
                },
              ),
            ],
          ),
        );

        expect(saved.sourcePath, 'notes/household/identity/smith-family.md');

        final reopened = LocalOrganoteRepository(fileStore: store);
        final snapshot = await reopened.reload();

        final note = snapshot.notes.single;
        expect(note.title, 'Smith Family');
        expect(note.categoryPath, 'household/identity');
        expect(note.records.map((record) => record.label), [
          'Person-1',
          'Person-2',
        ]);
        expect(note.records[0].values['name'], 'Ahmad');
        expect(note.records[1].values['name'], 'Sarah');
        expect(note.records[1].values['dob'], '01-01-2000 | 24-09-1420 H');
        await reopened.dispose();
      },
    );

    test(
      'saveRawSource rewrites the file on disk and re-parses the note',
      () async {
        final original = await repository.saveStructuredNote(
          const NoteInput(
            title: 'Editable Note',
            tags: ['draft'],
            records: [
              NoteRecord(label: 'Record', values: {'Field': 'before'}),
            ],
          ),
        );

        final newSource =
            '''
# Editable Note

## Record
- **Field**: after

---

## Metadata
- id: ${original.id}
- tags: published
''';

        final parsed = await repository.saveRawSource(original.id, newSource);

        expect(parsed.id, original.id);
        expect(parsed.records.single.values['field'], 'after');

        final reloaded = await repository.getNote(original.id);
        expect(reloaded?.records.single.values['field'], 'after');
        expect(reloaded?.tags, contains('published'));

        final disk = await store.readText(original.sourcePath!);
        expect(disk, equals(newSource));
      },
    );

    test('saveRawSource throws StateError for an unknown note id', () async {
      await repository.reload();
      expect(
        () => repository.saveRawSource('does-not-exist', '# anything'),
        throwsStateError,
      );
    });
  });
}
