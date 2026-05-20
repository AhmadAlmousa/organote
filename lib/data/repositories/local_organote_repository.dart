import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../../services/backup/backup_service.dart';
import '../../services/compliance/compliance_service.dart';
import '../../services/storage/file_store.dart';
import '../markdown/markdown_codec.dart';

class LocalOrganoteRepository
    implements
        LibraryRepository,
        NoteRepository,
        TemplateRepository,
        CategoryRepository,
        AssetRepository,
        ComplianceRepository,
        BackupRepository {
  LocalOrganoteRepository({
    required FileStore fileStore,
    MarkdownCodec markdownCodec = const MarkdownCodec(),
    ComplianceService complianceService = const ComplianceService(),
    SyncRepository? syncRepository,
  }) : _fileStore = fileStore,
       _markdownCodec = markdownCodec,
       _complianceService = complianceService,
       _backupService = BackupService(fileStore) {
    _syncSubscription = syncRepository?.watchSyncStatus().listen((status) {
      _syncStatus = status;
      final snapshot = _snapshot;
      if (snapshot != null) {
        _emit(snapshot: _snapshotWith(syncStatus: status));
      }
    });
  }

  static const _trashIndexPath = '.organote/trash.json';
  static const _categoriesPath = '.organote/categories.json';
  static const _complianceIgnoresPath = '.organote/compliance_ignores.json';

  final FileStore _fileStore;
  final MarkdownCodec _markdownCodec;
  final ComplianceService _complianceService;
  final BackupService _backupService;
  final StreamController<LibrarySnapshot> _libraryController =
      StreamController<LibrarySnapshot>.broadcast();
  final StreamController<ComplianceSummary> _complianceController =
      StreamController<ComplianceSummary>.broadcast();
  final StreamController<List<TrashEntry>> _trashController =
      StreamController<List<TrashEntry>>.broadcast();

  StreamSubscription<SyncStatus>? _syncSubscription;
  LibrarySnapshot? _snapshot;
  SyncStatus _syncStatus = const SyncStatus();

  @override
  Stream<LibrarySnapshot> watchLibrary() async* {
    final existing = _snapshot;
    if (existing != null) {
      yield existing;
    }
    yield* _libraryController.stream;
  }

  @override
  Stream<ComplianceSummary> watchComplianceSummary() async* {
    final existing = _snapshot?.complianceSummary;
    if (existing != null) {
      yield existing;
    }
    yield* _complianceController.stream;
  }

  @override
  Stream<List<TrashEntry>> watchTrash() async* {
    final existing = _snapshot?.trash;
    if (existing != null) {
      yield existing;
    }
    yield* _trashController.stream;
  }

  @override
  Future<LibrarySnapshot> reload() async {
    await _fileStore.ensureStructure();
    final templates = await _loadTemplates();
    final notes = await _loadNotes();
    final trash = await _readTrashEntries();
    final ignoredIssueIds = await _readIgnoredIssueIds();
    final categories = await _buildCategories(notes);
    final tags = notes.expand((note) => note.tags).toSet().toList()..sort();
    final complianceSummary = _complianceService.scan(
      templates: templates,
      notes: notes,
      ignoredIssueIds: ignoredIssueIds,
    );
    final snapshot = LibrarySnapshot(
      notes: notes,
      templates: templates,
      categories: categories,
      trash: trash,
      tags: tags,
      complianceSummary: complianceSummary,
      syncStatus: _syncStatus,
    );
    _emit(snapshot: snapshot);
    return snapshot;
  }

  @override
  Future<Note?> getNote(String id) async {
    final snapshot = _snapshot ?? await reload();
    return snapshot.notes.where((note) => note.id == id).firstOrNull;
  }

  @override
  Future<String> getRawSource(String id) async {
    final note = await getNote(id);
    final sourcePath = note?.sourcePath;
    if (sourcePath == null) {
      throw StateError('Cannot read raw source for unknown note $id.');
    }
    return _fileStore.readText(sourcePath);
  }

  @override
  Future<Template?> getTemplate(String id) async {
    final snapshot = _snapshot ?? await reload();
    return snapshot.templates
        .where((template) => template.id == id)
        .firstOrNull;
  }

  @override
  Future<Note> saveStructuredNote(NoteInput input) async {
    final now = DateTime.now().toUtc();
    final existing = input.id == null ? null : await getNote(input.id!);
    final id = input.id ?? _newId();
    final note = Note(
      id: id,
      title: input.title,
      templateId: input.templateId,
      templateName: input.templateName,
      templateVersion: input.templateVersion,
      icon: input.icon,
      tags: input.tags,
      categoryPath: normalizeRelativePath(input.categoryPath),
      records: input.records,
      body: input.body,
      isPinned: input.isPinned,
      isFavorite: input.isFavorite,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final relativePath = await _notePathFor(
      note,
      existingPath: existing?.sourcePath,
    );
    await _fileStore.writeText(
      relativePath,
      _markdownCodec.encodeNote(note.copyWith(sourcePath: relativePath)),
    );
    if (existing?.sourcePath != null && existing!.sourcePath != relativePath) {
      await _fileStore.delete(existing.sourcePath!);
    }
    await reload();
    return note.copyWith(sourcePath: relativePath);
  }

  @override
  Future<Note> saveRawSource(String id, String source) async {
    final existing = await getNote(id);
    if (existing?.sourcePath == null) {
      throw StateError('Cannot save raw source for unknown note $id.');
    }
    final parsed = _markdownCodec
        .decodeNote(source, sourcePath: existing!.sourcePath)
        .copyWith(id: id, updatedAt: DateTime.now().toUtc());
    await _fileStore.writeText(existing.sourcePath!, source);
    await reload();
    return parsed;
  }

  @override
  Future<void> setPinned(String noteId, bool value) async {
    await _setNoteFlags(noteId, isPinned: value);
  }

  @override
  Future<void> setFavorite(String noteId, bool value) async {
    await _setNoteFlags(noteId, isFavorite: value);
  }

  @override
  Future<void> softDeleteNote(String id) async {
    final note = await getNote(id);
    final sourcePath = note?.sourcePath;
    if (note == null || sourcePath == null) {
      return;
    }
    final trashPath = p.posix.join(
      'trash',
      'notes',
      '${DateTime.now().millisecondsSinceEpoch}_${p.posix.basename(sourcePath)}',
    );
    await _fileStore.move(sourcePath, trashPath);
    await _appendTrashEntry(
      TrashEntry(
        id: _newId(),
        originalPath: sourcePath,
        trashPath: trashPath,
        deletedAt: DateTime.now().toUtc(),
        type: TrashEntryType.note,
        checksum: checksumText(await _fileStore.readText(trashPath)),
      ),
    );
    await reload();
  }

  @override
  Future<void> restoreFromTrash(String trashEntryId) async {
    final entries = await _readTrashEntries();
    final entry = entries.where((item) => item.id == trashEntryId).firstOrNull;
    if (entry == null) {
      return;
    }
    await _fileStore.move(entry.trashPath, entry.originalPath);
    await _writeTrashEntries(
      entries.where((item) => item.id != trashEntryId).toList(),
    );
    await reload();
  }

  @override
  Future<void> purgeTrashEntry(String trashEntryId) async {
    final entries = await _readTrashEntries();
    final entry = entries.where((item) => item.id == trashEntryId).firstOrNull;
    if (entry == null) {
      return;
    }
    await _fileStore.delete(entry.trashPath, recursive: true);
    await _writeTrashEntries(
      entries.where((item) => item.id != trashEntryId).toList(),
    );
    await reload();
  }

  @override
  Future<Template> saveTemplate(TemplateInput input) async {
    final now = DateTime.now().toUtc();
    final existing = input.id == null ? null : await getTemplate(input.id!);
    final id = input.id ?? sanitizeFileName(input.name);
    final template = Template(
      id: id,
      name: input.name,
      version: input.version,
      icon: input.icon,
      defaultCategory: input.defaultCategory,
      layout: input.layout,
      fields: input.fields,
      updatedAt: now,
    );
    final path = await _templatePathFor(
      template,
      existingPath: existing?.sourcePath,
    );
    await _fileStore.writeText(
      path,
      _markdownCodec.encodeTemplate(template.copyWith(sourcePath: path)),
    );
    if (existing?.sourcePath != null && existing!.sourcePath != path) {
      await _fileStore.delete(existing.sourcePath!);
    }
    await reload();
    return template.copyWith(sourcePath: path);
  }

  @override
  Future<void> deleteTemplate(String id) async {
    final template = await getTemplate(id);
    final sourcePath = template?.sourcePath;
    if (sourcePath == null) {
      return;
    }
    final trashPath = p.posix.join(
      'trash',
      'templates',
      '${DateTime.now().millisecondsSinceEpoch}_${p.posix.basename(sourcePath)}',
    );
    await _fileStore.move(sourcePath, trashPath);
    await _appendTrashEntry(
      TrashEntry(
        id: _newId(),
        originalPath: sourcePath,
        trashPath: trashPath,
        deletedAt: DateTime.now().toUtc(),
        type: TrashEntryType.template,
      ),
    );
    await reload();
  }

  @override
  Future<Category> saveCategory(Category category) async {
    final categories = await _readCategoryMetadata();
    categories[category.path] = category.colorHex;
    await _writeCategoryMetadata(categories);
    await _fileStore.createDirectory(p.posix.join('notes', category.path));
    await reload();
    return category;
  }

  @override
  Future<void> moveCategory(String fromPath, String toPath) async {
    final from = normalizeRelativePath(p.posix.join('notes', fromPath));
    final to = normalizeRelativePath(p.posix.join('notes', toPath));
    if (await _fileStore.exists(from)) {
      await _fileStore.move(from, to);
    }
    final categories = await _readCategoryMetadata();
    final color = categories.remove(normalizeRelativePath(fromPath));
    if (color != null) {
      categories[normalizeRelativePath(toPath)] = color;
      await _writeCategoryMetadata(categories);
    }
    await reload();
  }

  @override
  Future<void> deleteCategory(String path) async {
    final normalized = normalizeRelativePath(path);
    final source = p.posix.join('notes', normalized);
    if (await _fileStore.exists(source)) {
      final trashPath = p.posix.join(
        'trash',
        'categories',
        '${DateTime.now().millisecondsSinceEpoch}_${sanitizeFileName(normalized)}',
      );
      await _fileStore.move(source, trashPath);
      await _appendTrashEntry(
        TrashEntry(
          id: _newId(),
          originalPath: source,
          trashPath: trashPath,
          deletedAt: DateTime.now().toUtc(),
          type: TrashEntryType.category,
        ),
      );
    }
    final categories = await _readCategoryMetadata();
    categories.remove(normalized);
    await _writeCategoryMetadata(categories);
    await reload();
  }

  @override
  Future<AssetRef> importImageForNote({
    required String noteId,
    required String originalName,
    required List<int> bytes,
    String? mediaType,
  }) async {
    final note = await getNote(noteId);
    if (note == null) {
      throw StateError('Cannot import an asset for unknown note $noteId.');
    }
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${sanitizeFileName(originalName)}';
    final relativePath = p.posix.join(
      'assets',
      sanitizeFileName(note.title),
      fileName,
    );
    await _fileStore.writeBytes(relativePath, bytes);
    return AssetRef(
      noteId: noteId,
      relativePath: relativePath,
      originalName: originalName,
      sizeBytes: bytes.length,
      mediaType: mediaType,
    );
  }

  @override
  Future<Uint8List> readAssetBytes(String relativePath) async {
    final path = normalizeRelativePath(relativePath);
    if (!path.startsWith('assets/')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Asset paths must be under assets/.',
      );
    }
    return Uint8List.fromList(await _fileStore.readBytes(path));
  }

  @override
  Future<ComplianceSummary> scanNow() async {
    final snapshot = await reload();
    return snapshot.complianceSummary;
  }

  @override
  Future<void> ignoreIssue(String issueId) async {
    final ignored = await _readIgnoredIssueIds();
    if (ignored.add(issueId)) {
      await _writeIgnoredIssueIds(ignored);
      await reload();
    }
  }

  @override
  Future<void> restoreIgnoredIssue(String issueId) async {
    final ignored = await _readIgnoredIssueIds();
    if (ignored.remove(issueId)) {
      await _writeIgnoredIssueIds(ignored);
      await reload();
    }
  }

  @override
  Future<List<int>> createBackupZip() => _backupService.createBackupZip();

  @override
  Future<void> restoreBackupZip(List<int> bytes) async {
    await _backupService.restoreBackupZip(bytes);
    await reload();
  }

  Future<List<Template>> _loadTemplates() async {
    final files = await _fileStore.listFiles('templates', recursive: true);
    final templates = <Template>[];
    for (final file in files.where(
      (file) => file.relativePath.endsWith('.md'),
    )) {
      final source = await _fileStore.readText(file.relativePath);
      templates.add(
        _markdownCodec.decodeTemplate(
          source,
          sourcePath: file.relativePath,
          updatedAt: file.modifiedAt,
        ),
      );
    }
    templates.sort((a, b) => a.name.compareTo(b.name));
    return templates;
  }

  Future<List<Note>> _loadNotes() async {
    final files = await _fileStore.listFiles('notes', recursive: true);
    final notes = <Note>[];
    for (final file in files.where(
      (file) => file.relativePath.endsWith('.md'),
    )) {
      final source = await _fileStore.readText(file.relativePath);
      notes.add(
        _markdownCodec.decodeNote(
          source,
          sourcePath: file.relativePath,
          updatedAt: file.modifiedAt,
        ),
      );
    }
    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    return notes;
  }

  Future<void> _setNoteFlags(
    String noteId, {
    bool? isPinned,
    bool? isFavorite,
  }) async {
    final note = await getNote(noteId);
    if (note == null) {
      return;
    }
    await saveStructuredNote(
      NoteInput(
        id: note.id,
        title: note.title,
        templateId: note.templateId,
        templateName: note.templateName,
        templateVersion: note.templateVersion,
        icon: note.icon,
        tags: note.tags,
        categoryPath: note.categoryPath,
        records: note.records,
        body: note.body,
        isPinned: isPinned ?? note.isPinned,
        isFavorite: isFavorite ?? note.isFavorite,
      ),
    );
  }

  Future<List<Category>> _buildCategories(List<Note> notes) async {
    final colors = await _readCategoryMetadata();
    final counts = <String, int>{};
    for (final note in notes) {
      final path = note.categoryPath;
      counts[path] = (counts[path] ?? 0) + 1;
      final parts = path.split('/').where((part) => part.isNotEmpty).toList();
      for (var index = 0; index < parts.length; index += 1) {
        final ancestor = parts.take(index + 1).join('/');
        counts.putIfAbsent(ancestor, () => 0);
      }
    }
    final paths = {
      ...counts.keys,
      ...colors.keys,
    }.where((path) => path.isNotEmpty).toList()..sort();
    return paths.map((path) {
      final parent = p.posix.dirname(path);
      return Category(
        path: path,
        name: p.posix.basename(path),
        parentPath: parent == '.' ? null : parent,
        colorHex: colors[path],
        noteCount: counts[path] ?? 0,
      );
    }).toList();
  }

  Future<String> _notePathFor(Note note, {String? existingPath}) async {
    final baseName = sanitizeFileName(note.title);
    final directory = p.posix.join('notes', note.categoryPath);
    return _collisionFreePath(
      p.posix.join(directory, '$baseName.md'),
      existingPath: existingPath,
    );
  }

  Future<String> _templatePathFor(Template template, {String? existingPath}) {
    return _collisionFreePath(
      p.posix.join('templates', '${sanitizeFileName(template.name)}.md'),
      existingPath: existingPath,
    );
  }

  Future<String> _collisionFreePath(
    String desiredPath, {
    String? existingPath,
  }) async {
    final normalized = normalizeRelativePath(desiredPath);
    if (existingPath == normalized || !await _fileStore.exists(normalized)) {
      return normalized;
    }
    final directory = p.posix.dirname(normalized);
    final extension = p.posix.extension(normalized);
    final base = p.posix.basenameWithoutExtension(normalized);
    var index = 2;
    while (true) {
      final candidate = p.posix.join(directory, '$base-$index$extension');
      if (candidate == existingPath || !await _fileStore.exists(candidate)) {
        return candidate;
      }
      index += 1;
    }
  }

  Future<void> _appendTrashEntry(TrashEntry entry) async {
    final entries = await _readTrashEntries();
    entries.add(entry);
    await _writeTrashEntries(entries);
  }

  Future<List<TrashEntry>> _readTrashEntries() async {
    if (!await _fileStore.exists(_trashIndexPath)) {
      return <TrashEntry>[];
    }
    final decoded =
        jsonDecode(await _fileStore.readText(_trashIndexPath)) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(
          (json) => TrashEntry(
            id: json['id'] as String,
            originalPath: json['originalPath'] as String,
            trashPath: json['trashPath'] as String,
            deletedAt: DateTime.parse(json['deletedAt'] as String),
            type: TrashEntryType.values.firstWhere(
              (type) => type.name == json['type'],
              orElse: () => TrashEntryType.other,
            ),
            checksum: json['checksum'] as String?,
          ),
        )
        .toList();
  }

  Future<void> _writeTrashEntries(List<TrashEntry> entries) {
    return _fileStore.writeText(
      _trashIndexPath,
      const JsonEncoder.withIndent('  ').convert(
        entries.map((entry) {
          return <String, Object?>{
            'id': entry.id,
            'originalPath': entry.originalPath,
            'trashPath': entry.trashPath,
            'deletedAt': entry.deletedAt.toIso8601String(),
            'type': entry.type.name,
            'checksum': entry.checksum,
          };
        }).toList(),
      ),
    );
  }

  Future<Set<String>> _readIgnoredIssueIds() async {
    if (!await _fileStore.exists(_complianceIgnoresPath)) {
      return <String>{};
    }
    final decoded =
        jsonDecode(await _fileStore.readText(_complianceIgnoresPath))
            as List<dynamic>;
    return decoded.cast<String>().toSet();
  }

  Future<void> _writeIgnoredIssueIds(Set<String> ids) {
    final ordered = ids.toList()..sort();
    return _fileStore.writeText(
      _complianceIgnoresPath,
      const JsonEncoder.withIndent('  ').convert(ordered),
    );
  }

  Future<Map<String, String?>> _readCategoryMetadata() async {
    if (!await _fileStore.exists(_categoriesPath)) {
      return <String, String?>{};
    }
    final decoded =
        jsonDecode(await _fileStore.readText(_categoriesPath))
            as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String?));
  }

  Future<void> _writeCategoryMetadata(Map<String, String?> categories) {
    return _fileStore.writeText(
      _categoriesPath,
      const JsonEncoder.withIndent('  ').convert(categories),
    );
  }

  void _emit({required LibrarySnapshot snapshot}) {
    _snapshot = snapshot;
    _libraryController.add(snapshot);
    _complianceController.add(snapshot.complianceSummary);
    _trashController.add(snapshot.trash);
  }

  LibrarySnapshot _snapshotWith({SyncStatus? syncStatus}) {
    final current = _snapshot ?? const LibrarySnapshot();
    return LibrarySnapshot(
      notes: current.notes,
      templates: current.templates,
      categories: current.categories,
      trash: current.trash,
      tags: current.tags,
      complianceSummary: current.complianceSummary,
      syncStatus: syncStatus ?? current.syncStatus,
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> dispose() async {
    await _syncSubscription?.cancel();
    await _libraryController.close();
    await _complianceController.close();
    await _trashController.close();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
