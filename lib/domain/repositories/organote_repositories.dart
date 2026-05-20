import 'dart:typed_data';

import '../models/organote_models.dart';

class TemplateInput {
  const TemplateInput({
    required this.name,
    required this.fields,
    this.id,
    this.version = 1,
    this.icon,
    this.defaultCategory,
    this.layout = TemplateLayout.cards,
  });

  final String? id;
  final String name;
  final int version;
  final String? icon;
  final String? defaultCategory;
  final TemplateLayout layout;
  final List<TemplateField> fields;
}

class NoteInput {
  const NoteInput({
    required this.title,
    required this.records,
    this.id,
    this.templateId,
    this.templateName,
    this.templateVersion = 0,
    this.icon,
    this.tags = const <String>[],
    this.categoryPath = '',
    this.body = '',
    this.isPinned = false,
    this.isFavorite = false,
  });

  final String? id;
  final String title;
  final String? templateId;
  final String? templateName;
  final int templateVersion;
  final String? icon;
  final List<String> tags;
  final String categoryPath;
  final List<NoteRecord> records;
  final String body;
  final bool isPinned;
  final bool isFavorite;
}

abstract interface class LibraryRepository {
  Stream<LibrarySnapshot> watchLibrary();

  Future<LibrarySnapshot> reload();
}

abstract interface class NoteRepository {
  Future<Note?> getNote(String id);

  Future<String> getRawSource(String id);

  Future<Note> saveStructuredNote(NoteInput input);

  Future<Note> saveRawSource(String id, String source);

  Future<void> setPinned(String noteId, bool value);

  Future<void> setFavorite(String noteId, bool value);

  Future<void> softDeleteNote(String id);

  Future<void> restoreFromTrash(String trashEntryId);

  Future<void> purgeTrashEntry(String trashEntryId);

  Stream<List<TrashEntry>> watchTrash();
}

abstract interface class TemplateRepository {
  Future<Template?> getTemplate(String id);

  Future<Template> saveTemplate(TemplateInput input);

  Future<void> deleteTemplate(String id);
}

abstract interface class CategoryRepository {
  Future<Category> saveCategory(Category category);

  Future<void> moveCategory(String fromPath, String toPath);

  Future<void> deleteCategory(String path);
}

abstract interface class AssetRepository {
  Future<AssetRef> importImageForNote({
    required String noteId,
    required String originalName,
    required List<int> bytes,
    String? mediaType,
  });

  Future<Uint8List> readAssetBytes(String relativePath);
}

abstract interface class ComplianceRepository {
  Stream<ComplianceSummary> watchComplianceSummary();

  Future<ComplianceSummary> scanNow();

  Future<void> ignoreIssue(String issueId);

  Future<void> restoreIgnoredIssue(String issueId);
}

abstract interface class SyncRepository {
  Stream<SyncStatus> watchSyncStatus();

  Future<void> signInGoogleDrive();

  Future<void> syncNow();
}

abstract interface class BackupRepository {
  Future<List<int>> createBackupZip();

  Future<void> restoreBackupZip(List<int> bytes);
}
