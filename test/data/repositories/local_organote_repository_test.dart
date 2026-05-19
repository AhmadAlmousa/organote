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
    });

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
  });
}
