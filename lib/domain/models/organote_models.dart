enum TemplateLayout {
  cards,
  table,
  grid;

  static TemplateLayout parse(String? value) {
    return TemplateLayout.values.firstWhere(
      (layout) => layout.name == value?.trim().toLowerCase(),
      orElse: () => TemplateLayout.cards,
    );
  }
}

enum TemplateFieldType {
  text,
  number,
  date,
  boolean,
  dropdown,
  password,
  url,
  ip,
  regex,
  image,
  customLabel;

  static TemplateFieldType parse(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'bool' || 'boolean' => TemplateFieldType.boolean,
      'custom' || 'custom_label' || 'label' => TemplateFieldType.customLabel,
      'uri' || 'url' => TemplateFieldType.url,
      'ip_address' || 'ip' => TemplateFieldType.ip,
      _ => TemplateFieldType.values.firstWhere(
        (type) => type.name.toLowerCase() == normalized,
        orElse: () => TemplateFieldType.text,
      ),
    };
  }

  String get storageName {
    return switch (this) {
      TemplateFieldType.customLabel => 'custom',
      TemplateFieldType.url => 'url',
      TemplateFieldType.ip => 'ip',
      _ => name,
    };
  }
}

enum CalendarMode {
  gregorian,
  hijri,
  dual;

  static CalendarMode parse(String? value) {
    return CalendarMode.values.firstWhere(
      (mode) => mode.name == value?.trim().toLowerCase(),
      orElse: () => CalendarMode.gregorian,
    );
  }
}

enum CalendarSystem {
  gregorian,
  hijri;

  static CalendarSystem parse(String? value) {
    return CalendarSystem.values.firstWhere(
      (system) => system.name == value?.trim().toLowerCase(),
      orElse: () => CalendarSystem.gregorian,
    );
  }
}

enum ComplianceIssueType {
  missingRequiredField,
  typeMismatch,
  versionDrift,
  orphanTemplateRef,
  renameCopySuggestion,
}

enum ComplianceSeverity { info, warning, error }

enum TrashEntryType { note, template, asset, category, other }

enum SyncPhase { idle, signingIn, scanning, syncing, complete, error }

enum SyncOverwriteItemType { note, template }

enum SyncOverwriteFreshness { local, remote, same }

enum ThemePreference { system, light, dark, oled }

class TemplateField {
  const TemplateField({
    required this.id,
    required this.label,
    required this.type,
    this.isRequired = false,
    this.hint,
    this.multiline = false,
    this.minLength,
    this.maxLength,
    this.digits,
    this.min,
    this.max,
    this.options = const <String>[],
    this.regex,
    this.calendarMode = CalendarMode.gregorian,
    this.primaryCalendar = CalendarSystem.gregorian,
  });

  final String id;
  final String label;
  final TemplateFieldType type;
  final bool isRequired;
  final String? hint;
  final bool multiline;
  final int? minLength;
  final int? maxLength;
  final int? digits;
  final num? min;
  final num? max;
  final List<String> options;
  final String? regex;
  final CalendarMode calendarMode;
  final CalendarSystem primaryCalendar;

  TemplateField copyWith({
    String? id,
    String? label,
    TemplateFieldType? type,
    bool? isRequired,
    String? hint,
    bool? multiline,
    int? minLength,
    int? maxLength,
    int? digits,
    num? min,
    num? max,
    List<String>? options,
    String? regex,
    CalendarMode? calendarMode,
    CalendarSystem? primaryCalendar,
  }) {
    return TemplateField(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      isRequired: isRequired ?? this.isRequired,
      hint: hint ?? this.hint,
      multiline: multiline ?? this.multiline,
      minLength: minLength ?? this.minLength,
      maxLength: maxLength ?? this.maxLength,
      digits: digits ?? this.digits,
      min: min ?? this.min,
      max: max ?? this.max,
      options: options ?? this.options,
      regex: regex ?? this.regex,
      calendarMode: calendarMode ?? this.calendarMode,
      primaryCalendar: primaryCalendar ?? this.primaryCalendar,
    );
  }
}

class Template {
  const Template({
    required this.id,
    required this.name,
    required this.version,
    required this.fields,
    this.icon,
    this.defaultCategory,
    this.layout = TemplateLayout.cards,
    this.sourcePath,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int version;
  final List<TemplateField> fields;
  final String? icon;
  final String? defaultCategory;
  final TemplateLayout layout;
  final String? sourcePath;
  final DateTime? updatedAt;

  Template copyWith({
    String? id,
    String? name,
    int? version,
    List<TemplateField>? fields,
    String? icon,
    String? defaultCategory,
    TemplateLayout? layout,
    String? sourcePath,
    DateTime? updatedAt,
  }) {
    return Template(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      fields: fields ?? this.fields,
      icon: icon ?? this.icon,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      layout: layout ?? this.layout,
      sourcePath: sourcePath ?? this.sourcePath,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteRecord {
  const NoteRecord({required this.label, required this.values, this.id});

  final String? id;
  final String label;
  final Map<String, String> values;

  NoteRecord copyWith({
    String? id,
    String? label,
    Map<String, String>? values,
  }) {
    return NoteRecord(
      id: id ?? this.id,
      label: label ?? this.label,
      values: values ?? this.values,
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.records,
    this.templateId,
    this.templateName,
    this.templateVersion = 0,
    this.icon,
    this.tags = const <String>[],
    this.categoryPath = '',
    this.body = '',
    this.isPinned = false,
    this.isFavorite = false,
    this.sourcePath,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
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
  final String? sourcePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Note copyWith({
    String? id,
    String? title,
    String? templateId,
    String? templateName,
    int? templateVersion,
    String? icon,
    List<String>? tags,
    String? categoryPath,
    List<NoteRecord>? records,
    String? body,
    bool? isPinned,
    bool? isFavorite,
    String? sourcePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      templateId: templateId ?? this.templateId,
      templateName: templateName ?? this.templateName,
      templateVersion: templateVersion ?? this.templateVersion,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      categoryPath: categoryPath ?? this.categoryPath,
      records: records ?? this.records,
      body: body ?? this.body,
      isPinned: isPinned ?? this.isPinned,
      isFavorite: isFavorite ?? this.isFavorite,
      sourcePath: sourcePath ?? this.sourcePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Category {
  const Category({
    required this.path,
    required this.name,
    this.parentPath,
    this.colorHex,
    this.noteCount = 0,
  });

  final String path;
  final String name;
  final String? parentPath;
  final String? colorHex;
  final int noteCount;
}

class AssetRef {
  const AssetRef({
    required this.noteId,
    required this.relativePath,
    required this.originalName,
    required this.sizeBytes,
    this.mediaType,
  });

  final String noteId;
  final String relativePath;
  final String originalName;
  final int sizeBytes;
  final String? mediaType;
}

class ComplianceIssue {
  const ComplianceIssue({
    required this.id,
    required this.type,
    required this.severity,
    required this.message,
    this.noteId,
    this.templateId,
    this.fieldLabel,
    this.legacyFieldLabel,
    this.ignored = false,
  });

  final String id;
  final ComplianceIssueType type;
  final ComplianceSeverity severity;
  final String message;
  final String? noteId;
  final String? templateId;
  final String? fieldLabel;
  final String? legacyFieldLabel;
  final bool ignored;
}

class ComplianceSummary {
  const ComplianceSummary({this.issues = const <ComplianceIssue>[]});

  final List<ComplianceIssue> issues;

  int get activeCount => issues.where((issue) => !issue.ignored).length;
  int get errorCount => issues
      .where(
        (issue) => !issue.ignored && issue.severity == ComplianceSeverity.error,
      )
      .length;
}

class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.originalPath,
    required this.trashPath,
    required this.deletedAt,
    required this.type,
    this.checksum,
  });

  final String id;
  final String originalPath;
  final String trashPath;
  final DateTime deletedAt;
  final TrashEntryType type;
  final String? checksum;
}

class SyncLedgerEntry {
  const SyncLedgerEntry({
    required this.relativePath,
    required this.localChecksum,
    required this.remoteModifiedAt,
    required this.localSyncedAt,
    this.remoteFileId,
    this.softDeleted = false,
  });

  final String relativePath;
  final String localChecksum;
  final DateTime remoteModifiedAt;
  final DateTime localSyncedAt;
  final String? remoteFileId;
  final bool softDeleted;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'relativePath': relativePath,
      'localChecksum': localChecksum,
      'remoteModifiedAt': remoteModifiedAt.toIso8601String(),
      'localSyncedAt': localSyncedAt.toIso8601String(),
      'remoteFileId': remoteFileId,
      'softDeleted': softDeleted,
    };
  }

  static SyncLedgerEntry fromJson(Map<String, Object?> json) {
    return SyncLedgerEntry(
      relativePath: json['relativePath'] as String,
      localChecksum: json['localChecksum'] as String,
      remoteModifiedAt: DateTime.parse(json['remoteModifiedAt'] as String),
      localSyncedAt: DateTime.parse(json['localSyncedAt'] as String),
      remoteFileId: json['remoteFileId'] as String?,
      softDeleted: json['softDeleted'] as bool? ?? false,
    );
  }
}

class SyncOverwriteWarning {
  const SyncOverwriteWarning({
    required this.relativePath,
    required this.itemType,
    required this.localModifiedAt,
    required this.remoteModifiedAt,
  });

  final String relativePath;
  final SyncOverwriteItemType itemType;
  final DateTime localModifiedAt;
  final DateTime remoteModifiedAt;

  SyncOverwriteFreshness get newerSide {
    if (remoteModifiedAt.isAfter(localModifiedAt)) {
      return SyncOverwriteFreshness.remote;
    }
    if (localModifiedAt.isAfter(remoteModifiedAt)) {
      return SyncOverwriteFreshness.local;
    }
    return SyncOverwriteFreshness.same;
  }
}

class AppSettings {
  const AppSettings({
    this.storageRootPath,
    this.localeCode = 'en',
    this.themePreference = ThemePreference.system,
    this.googleDriveEnabled = false,
  });

  final String? storageRootPath;
  final String localeCode;
  final ThemePreference themePreference;
  final bool googleDriveEnabled;

  bool get oledMode => themePreference == ThemePreference.oled;

  AppSettings copyWith({
    String? storageRootPath,
    String? localeCode,
    ThemePreference? themePreference,
    bool? googleDriveEnabled,
  }) {
    return AppSettings(
      storageRootPath: storageRootPath ?? this.storageRootPath,
      localeCode: localeCode ?? this.localeCode,
      themePreference: themePreference ?? this.themePreference,
      googleDriveEnabled: googleDriveEnabled ?? this.googleDriveEnabled,
    );
  }
}

class SyncStatus {
  const SyncStatus({
    this.phase = SyncPhase.idle,
    this.message,
    this.lastSyncAt,
    this.pendingChanges = 0,
    this.conflictCount = 0,
    this.signedIn = false,
  });

  final SyncPhase phase;
  final String? message;
  final DateTime? lastSyncAt;
  final int pendingChanges;
  final int conflictCount;
  final bool signedIn;

  SyncStatus copyWith({
    SyncPhase? phase,
    String? message,
    DateTime? lastSyncAt,
    int? pendingChanges,
    int? conflictCount,
    bool? signedIn,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      conflictCount: conflictCount ?? this.conflictCount,
      signedIn: signedIn ?? this.signedIn,
    );
  }
}

class LibrarySnapshot {
  const LibrarySnapshot({
    this.notes = const <Note>[],
    this.templates = const <Template>[],
    this.categories = const <Category>[],
    this.trash = const <TrashEntry>[],
    this.tags = const <String>[],
    this.complianceSummary = const ComplianceSummary(),
    this.syncStatus = const SyncStatus(),
  });

  final List<Note> notes;
  final List<Template> templates;
  final List<Category> categories;
  final List<TrashEntry> trash;
  final List<String> tags;
  final ComplianceSummary complianceSummary;
  final SyncStatus syncStatus;
}
