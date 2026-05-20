import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
import 'package:organote/ui/screens/note_editor/note_editor_screen.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:organote/ui/state/library_provider.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';
import 'package:organote/ui/theme/density.dart';

void main() {
  group('NoteEditorScreen', () {
    final template = Template(
      id: 'server-login',
      name: 'Server Login',
      version: 1,
      icon: '🖥',
      updatedAt: DateTime(2026, 5, 20, 9),
      fields: const <TemplateField>[
        TemplateField(
          id: 'host',
          label: 'Host',
          type: TemplateFieldType.ip,
          isRequired: true,
        ),
        TemplateField(
          id: 'password',
          label: 'Password',
          type: TemplateFieldType.password,
          isRequired: true,
        ),
        TemplateField(
          id: 'env',
          label: 'Environment',
          type: TemplateFieldType.dropdown,
          options: <String>['prod', 'stage', 'dev'],
        ),
      ],
    );

    LibrarySnapshot makeSnapshot() {
      return LibrarySnapshot(templates: <Template>[template]);
    }

    testWidgets('seeds from template and renders one record', (tester) async {
      final fake = _FakeNoteRepo();
      await tester.pumpWidget(
        _EditorHarness(
          snapshot: makeSnapshot(),
          noteRepo: fake,
          templateId: template.id,
        ),
      );
      await tester.pump();

      expect(find.text('Server Login'), findsWidgets);
      expect(find.text('Server Login 1'), findsWidgets);
      expect(find.text('HOST'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
      expect(find.text('ENVIRONMENT'), findsOneWidget);
    });

    testWidgets('autosaves once after 2 seconds of typing', (tester) async {
      final fake = _FakeNoteRepo();
      await tester.pumpWidget(
        _EditorHarness(
          snapshot: makeSnapshot(),
          noteRepo: fake,
          templateId: template.id,
        ),
      );
      await tester.pump();

      final titleField = find.widgetWithText(TextField, 'Untitled note');
      await tester.enterText(titleField, 'Prod DB');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(titleField, 'Prod DB primary');
      await tester.pump(const Duration(milliseconds: 1500));
      // Still inside the debounce window.
      expect(fake.savedInputs, isEmpty);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(fake.savedInputs, hasLength(1));
      expect(fake.savedInputs.single.title, 'Prod DB primary');
      expect(fake.savedInputs.single.templateId, 'server-login');
    });

    testWidgets('queues edits made while a save is in flight', (tester) async {
      final fake = _BlockingNoteRepo();
      await tester.pumpWidget(
        _EditorHarness(
          snapshot: makeSnapshot(),
          noteRepo: fake,
          templateId: template.id,
        ),
      );
      await tester.pump();

      final titleField = find.byKey(const Key('note-title-field'));
      await tester.enterText(titleField, 'First draft');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(fake.savedInputs, hasLength(1));
      expect(fake.savedInputs.single.title, 'First draft');
      expect(fake.pendingCount, 1);

      await tester.enterText(titleField, 'Second draft');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(fake.savedInputs, hasLength(1));

      fake.completeNext();
      await tester.pump();
      await tester.pump();

      expect(fake.savedInputs, hasLength(2));
      expect(fake.savedInputs.last.title, 'Second draft');

      fake.completeNext();
      await tester.pump();
    });

    testWidgets('add record adds a draft and remove tears it down', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fake = _FakeNoteRepo();
      await tester.pumpWidget(
        _EditorHarness(
          snapshot: makeSnapshot(),
          noteRepo: fake,
          templateId: template.id,
        ),
      );
      await tester.pump();

      expect(find.text('Server Login 1'), findsWidgets);
      expect(find.text('Server Login 2'), findsNothing);

      final addButton = find.text('Add server login record');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Server Login 1'), findsWidgets);
      expect(find.text('Server Login 2'), findsWidgets);

      final removeButtons = find.byTooltip('Remove record');
      expect(removeButtons, findsNWidgets(2));
      await tester.ensureVisible(removeButtons.first);
      await tester.tap(removeButtons.last);
      await tester.pumpAndSettle();

      expect(find.text('Server Login 2'), findsNothing);
    });

    testWidgets('Done flushes any pending edits before popping', (
      tester,
    ) async {
      final fake = _FakeNoteRepo();
      await tester.pumpWidget(
        _EditorHarness(
          snapshot: makeSnapshot(),
          noteRepo: fake,
          templateId: template.id,
        ),
      );
      await tester.pump();

      final titleField = find.widgetWithText(TextField, 'Untitled note');
      await tester.enterText(titleField, 'Quick draft');
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('Done').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fake.savedInputs, hasLength(1));
      expect(fake.savedInputs.single.title, 'Quick draft');
    });

    testWidgets('specialized fields save formatted values', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final specialized = Template(
        id: 'incident',
        name: 'Incident',
        version: 1,
        fields: const <TemplateField>[
          TemplateField(
            id: 'follow_up',
            label: 'Follow-up',
            type: TemplateFieldType.date,
            calendarMode: CalendarMode.dual,
          ),
          TemplateField(
            id: 'ticket',
            label: 'Ticket',
            type: TemplateFieldType.regex,
            regex: r'^[A-Z]{3}-\d{3}$',
            hint: 'ABC-123',
          ),
          TemplateField(
            id: 'contact',
            label: 'Contact',
            type: TemplateFieldType.customLabel,
          ),
        ],
      );
      final fake = _FakeNoteRepo();
      await tester.pumpWidget(
        _EditorHarness(
          snapshot: LibrarySnapshot(templates: <Template>[specialized]),
          noteRepo: fake,
          templateId: specialized.id,
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('regex-field-ticket')),
        'ABC-123',
      );
      await tester.enterText(
        find.byKey(const Key('custom-label-contact-label')),
        'Owner',
      );
      await tester.enterText(
        find.byKey(const Key('custom-label-contact-value')),
        'Ahmed',
      );

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(fake.savedInputs, isNotEmpty);
      final values = fake.savedInputs.last.records.single.values;
      expect(values['Follow-up'], contains(' | '));
      expect(values['Follow-up'], endsWith(' H'));
      expect(values['Ticket'], 'ABC-123');
      expect(values['Contact'], 'Owner: Ahmed');
    });
  });
}

class _EditorHarness extends StatelessWidget {
  const _EditorHarness({
    required this.snapshot,
    required this.noteRepo,
    this.templateId,
  });

  final LibrarySnapshot snapshot;
  final NoteRepository noteRepo;
  final String? templateId;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );
    return ProviderScope(
      overrides: [
        librarySnapshotProvider.overrideWithValue(snapshot),
        noteRepositoryProvider.overrideWithValue(noteRepo),
        categoryRepositoryProvider.overrideWithValue(_StubCategoryRepo()),
        assetRepositoryProvider.overrideWithValue(_StubAssetRepo()),
      ],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: OrgDensity(
            level: OrgDensityLevel.comfortable,
            child: NoteEditorScreen(templateId: templateId),
          ),
        ),
      ),
    );
  }
}

class _FakeNoteRepo implements NoteRepository {
  final List<NoteInput> savedInputs = <NoteInput>[];

  @override
  Future<Note> saveStructuredNote(NoteInput input) async {
    savedInputs.add(input);
    final id = input.id ?? 'fake-${savedInputs.length}';
    return Note(
      id: id,
      title: input.title,
      templateId: input.templateId,
      templateName: input.templateName,
      templateVersion: input.templateVersion,
      icon: input.icon,
      tags: input.tags,
      categoryPath: input.categoryPath,
      records: input.records,
      body: input.body,
      isPinned: input.isPinned,
      isFavorite: input.isFavorite,
      updatedAt: DateTime(2026, 5, 20, 12),
    );
  }

  @override
  Future<Note?> getNote(String id) async => null;

  @override
  Future<String> getRawSource(String id) async => '';

  @override
  Future<Note> saveRawSource(String id, String source) async =>
      throw UnimplementedError();

  @override
  Future<void> setPinned(String noteId, bool value) async {}

  @override
  Future<void> setFavorite(String noteId, bool value) async {}

  @override
  Future<void> softDeleteNote(String id) async {}

  @override
  Future<void> restoreFromTrash(String trashEntryId) async {}

  @override
  Future<void> purgeTrashEntry(String trashEntryId) async {}

  @override
  Stream<List<TrashEntry>> watchTrash() => const Stream.empty();
}

class _BlockingNoteRepo implements NoteRepository {
  final List<NoteInput> savedInputs = <NoteInput>[];
  final List<_PendingSave> _pending = <_PendingSave>[];

  int get pendingCount => _pending.length;

  @override
  Future<Note> saveStructuredNote(NoteInput input) {
    savedInputs.add(input);
    final completer = Completer<Note>();
    _pending.add(_PendingSave(input, completer));
    return completer.future;
  }

  void completeNext() {
    final pending = _pending.removeAt(0);
    pending.completer.complete(
      Note(
        id: pending.input.id ?? 'fake-${savedInputs.length}',
        title: pending.input.title,
        templateId: pending.input.templateId,
        templateName: pending.input.templateName,
        templateVersion: pending.input.templateVersion,
        icon: pending.input.icon,
        tags: pending.input.tags,
        categoryPath: pending.input.categoryPath,
        records: pending.input.records,
        body: pending.input.body,
        isPinned: pending.input.isPinned,
        isFavorite: pending.input.isFavorite,
        updatedAt: DateTime(2026, 5, 20, 12),
      ),
    );
  }

  @override
  Future<Note?> getNote(String id) async => null;

  @override
  Future<String> getRawSource(String id) async => '';

  @override
  Future<Note> saveRawSource(String id, String source) async =>
      throw UnimplementedError();

  @override
  Future<void> setPinned(String noteId, bool value) async {}

  @override
  Future<void> setFavorite(String noteId, bool value) async {}

  @override
  Future<void> softDeleteNote(String id) async {}

  @override
  Future<void> restoreFromTrash(String trashEntryId) async {}

  @override
  Future<void> purgeTrashEntry(String trashEntryId) async {}

  @override
  Stream<List<TrashEntry>> watchTrash() => const Stream.empty();
}

class _PendingSave {
  const _PendingSave(this.input, this.completer);

  final NoteInput input;
  final Completer<Note> completer;
}

class _StubCategoryRepo implements CategoryRepository {
  @override
  Future<Category> saveCategory(Category category) async => category;

  @override
  Future<void> moveCategory(String fromPath, String toPath) async {}

  @override
  Future<void> deleteCategory(String path) async {}
}

class _StubAssetRepo implements AssetRepository {
  @override
  Future<AssetRef> importImageForNote({
    required String noteId,
    required String originalName,
    required List<int> bytes,
    String? mediaType,
  }) async {
    return AssetRef(
      noteId: noteId,
      relativePath: 'assets/$noteId/$originalName',
      originalName: originalName,
      sizeBytes: bytes.length,
      mediaType: mediaType,
    );
  }

  @override
  Future<Uint8List> readAssetBytes(String relativePath) async {
    return Uint8List.fromList(<int>[]);
  }
}
