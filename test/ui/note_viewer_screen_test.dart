import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
import 'package:organote/ui/screens/note_viewer/note_viewer_screen.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:organote/ui/state/library_provider.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';
import 'package:organote/ui/theme/density.dart';

void main() {
  testWidgets('NoteViewerScreen renders image fields from asset bytes', (
    tester,
  ) async {
    final assetRepo = _FakeAssetRepo();
    const imagePath = 'assets/prod-db/photo.png';
    final template = Template(
      id: 'server-login',
      name: 'Server Login',
      version: 1,
      fields: const <TemplateField>[
        TemplateField(
          id: 'photo',
          label: 'Photo',
          type: TemplateFieldType.image,
        ),
      ],
    );
    final snapshot = LibrarySnapshot(
      templates: <Template>[template],
      notes: <Note>[
        Note(
          id: 'prod-db',
          title: 'Prod DB',
          templateId: template.id,
          templateName: template.name,
          records: const <NoteRecord>[
            NoteRecord(
              label: 'Primary',
              values: <String, String>{'Photo': imagePath},
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _ViewerHarness(snapshot: snapshot, assetRepository: assetRepo),
    );
    await tester.pump();
    await tester.pump();

    expect(assetRepo.readPaths, <String>[imagePath]);
    expect(find.text('PHOTO'), findsOneWidget);
    expect(find.text('PHASE 6'), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('NoteViewerScreen renders normalized multi-image field values', (
    tester,
  ) async {
    final assetRepo = _FakeAssetRepo();
    const firstPath = 'assets/prod-db/rack-front.png';
    const secondPath = 'assets/prod-db/rack-back.jpg';
    final template = Template(
      id: 'server-login',
      name: 'Server Login',
      version: 1,
      fields: const <TemplateField>[
        TemplateField(
          id: 'rack_photo',
          label: 'Rack Photo',
          type: TemplateFieldType.image,
        ),
      ],
    );
    final snapshot = LibrarySnapshot(
      templates: <Template>[template],
      notes: <Note>[
        Note(
          id: 'prod-db',
          title: 'Prod DB',
          templateId: template.id,
          templateName: template.name,
          records: const <NoteRecord>[
            NoteRecord(
              label: 'Primary',
              values: <String, String>{'rack photo': '$firstPath, $secondPath'},
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      _ViewerHarness(snapshot: snapshot, assetRepository: assetRepo),
    );
    await tester.pump();
    await tester.pump();

    expect(assetRepo.readPaths, containsAllInOrder([firstPath, secondPath]));
    expect(find.text('RACK PHOTO'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('viewer-image-$firstPath')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('NoteViewerScreen opens raw source editor and saves edits', (
    tester,
  ) async {
    final noteRepo = _FakeNoteRepo(
      rawSource: '# Prod DB\n\n## Primary\n- **Host**: 10.0.0.1',
    );
    final snapshot = LibrarySnapshot(
      notes: <Note>[
        Note(
          id: 'prod-db',
          title: 'Prod DB',
          records: const <NoteRecord>[
            NoteRecord(
              label: 'Primary',
              values: <String, String>{'Host': '10.0.0.1'},
            ),
          ],
          sourcePath: 'notes/prod-db.md',
        ),
      ],
    );

    await tester.pumpWidget(
      _ViewerHarness(
        snapshot: snapshot,
        assetRepository: _FakeAssetRepo(),
        noteRepository: noteRepo,
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw source'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(noteRepo.readIds, <String>['prod-db']);
    final editor = find.byKey(const Key('raw-source-editor-field'));
    expect(editor, findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller?.text,
      contains('10.0.0.1'),
    );

    await tester.enterText(editor, '# Prod DB\n\nUpdated raw body');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(noteRepo.savedSources, <String>['# Prod DB\n\nUpdated raw body']);
    expect(find.text('Saved'), findsOneWidget);
  });
}

class _ViewerHarness extends StatelessWidget {
  const _ViewerHarness({
    required this.snapshot,
    required this.assetRepository,
    this.noteRepository,
  });

  final LibrarySnapshot snapshot;
  final AssetRepository assetRepository;
  final NoteRepository? noteRepository;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );

    return ProviderScope(
      overrides: [
        librarySnapshotProvider.overrideWithValue(snapshot),
        assetRepositoryProvider.overrideWithValue(assetRepository),
        if (noteRepository != null)
          noteRepositoryProvider.overrideWithValue(noteRepository!),
      ],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: const OrgDensity(
            level: OrgDensityLevel.comfortable,
            child: NoteViewerScreen(noteId: 'prod-db'),
          ),
        ),
      ),
    );
  }
}

class _FakeNoteRepo implements NoteRepository {
  _FakeNoteRepo({required this.rawSource});

  final String rawSource;
  final List<String> readIds = <String>[];
  final List<String> savedSources = <String>[];

  @override
  Future<String> getRawSource(String id) async {
    readIds.add(id);
    return rawSource;
  }

  @override
  Future<Note> saveRawSource(String id, String source) async {
    savedSources.add(source);
    return Note(id: id, title: 'Prod DB', records: const <NoteRecord>[]);
  }

  @override
  Future<Note?> getNote(String id) async => null;

  @override
  Future<Note> saveStructuredNote(NoteInput input) async =>
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

class _FakeAssetRepo implements AssetRepository {
  final List<String> readPaths = <String>[];

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
    readPaths.add(relativePath);
    return Uint8List.fromList(_transparentPng);
  }
}

const List<int> _transparentPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  248,
  15,
  4,
  0,
  9,
  251,
  3,
  253,
  160,
  111,
  85,
  221,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
