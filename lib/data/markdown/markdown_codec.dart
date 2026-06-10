import 'package:path/path.dart' as p;

import '../../domain/models/models.dart';
import '../../services/storage/file_store.dart';

class MarkdownCodec {
  const MarkdownCodec();

  static const _bodySentinel = '<!-- organote:body -->';

  String encodeTemplate(Template template) {
    final buffer = StringBuffer()
      ..writeln('# ${template.name}')
      ..writeln()
      ..writeln('## Metadata')
      ..writeln('- **template name**: ${template.name}')
      ..writeln('- **template ver**: ${template.version}')
      ..writeln('- **id**: ${template.id}')
      ..writeln('- **icon**: ${template.icon ?? ''}')
      ..writeln('- **default category**: ${template.defaultCategory ?? ''}')
      ..writeln('- **layout**: ${template.layout.name}')
      ..writeln();

    for (final field in template.fields) {
      buffer
        ..writeln('## ${field.label}')
        ..writeln('- **type**: ${field.type.storageName}')
        ..writeln('- **id**: ${field.id}')
        ..writeln('- **required**: ${field.isRequired}')
        ..writeln('- **hint**: ${field.hint ?? ''}');
      if (field.type == TemplateFieldType.text ||
          field.type == TemplateFieldType.password) {
        buffer.writeln('- **multiline**: ${field.multiline}');
      }
      _writeOptional(buffer, 'minlength', field.minLength);
      _writeOptional(buffer, 'maxlength', field.maxLength);
      _writeOptional(buffer, 'digits', field.digits);
      _writeOptional(buffer, 'min', field.min);
      _writeOptional(buffer, 'max', field.max);
      if (field.options.isNotEmpty) {
        buffer.writeln('- **options**: ${field.options.join(', ')}');
      }
      _writeOptional(buffer, 'regex', field.regex);
      if (field.type == TemplateFieldType.date) {
        buffer
          ..writeln('- **calendar mode**: ${field.calendarMode.name}')
          ..writeln('- **primary**: ${field.primaryCalendar.name}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  Template decodeTemplate(
    String source, {
    String? sourcePath,
    DateTime? updatedAt,
  }) {
    final title = _titleOf(source);
    final sections = _sectionsOf(source);
    final metadata = sections.firstWhere(
      (section) => _sameKey(section.title, 'metadata'),
      orElse: () => const _MarkdownSection(title: 'Metadata'),
    );
    final metadataValues = _rowMap(metadata.rows);
    final name = metadataValues['template name'] ?? title;
    final id = metadataValues['id'] ?? sanitizeFileName(name);
    final version = int.tryParse(metadataValues['template ver'] ?? '') ?? 1;
    final fields = sections
        .where((section) => !_sameKey(section.title, 'metadata'))
        .map(_fieldFromSection)
        .toList();

    return Template(
      id: id,
      name: name,
      version: version,
      icon: _emptyToNull(metadataValues['icon']),
      defaultCategory: _emptyToNull(metadataValues['default category']),
      layout: TemplateLayout.parse(metadataValues['layout']),
      fields: fields,
      sourcePath: sourcePath,
      updatedAt: updatedAt,
    );
  }

  String encodeNote(Note note) {
    final buffer = StringBuffer()
      ..writeln('# ${note.title}')
      ..writeln();
    for (final record in note.records) {
      final heading = _headingForRecord(note, record);
      buffer
        ..writeln('## ${heading.title}')
        ..writeln('- **record id**: ${record.id ?? ''}');
      for (final entry in record.values.entries) {
        if (entry.key == heading.omittedValueKey) {
          continue;
        }
        _writeRow(buffer, entry.key, entry.value);
      }
      buffer.writeln();
    }
    if (note.body.trim().isNotEmpty) {
      buffer
        ..writeln('## Body')
        ..writeln(_bodySentinel)
        ..writeln(note.body.trimRight())
        ..writeln();
    }
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('## Metadata')
      ..writeln('- **template id**: ${note.templateId ?? ''}')
      ..writeln('- **template name**: ${note.templateName ?? ''}')
      ..writeln('- **template ver**: ${note.templateVersion}')
      ..writeln('- **id**: ${note.id}')
      ..writeln('- **icon**: ${note.icon ?? ''}')
      ..writeln('- **category**: ${note.categoryPath}')
      ..writeln('- **tags**: ${note.tags.join(', ')}')
      ..writeln('- **pinned**: ${note.isPinned}')
      ..writeln('- **favorite**: ${note.isFavorite}')
      ..writeln('- **created at**: ${note.createdAt?.toIso8601String() ?? ''}')
      ..writeln('- **updated at**: ${note.updatedAt?.toIso8601String() ?? ''}');
    return buffer.toString();
  }

  Note decodeNote(String source, {String? sourcePath, DateTime? updatedAt}) {
    final title = _titleOf(source);
    final parts = _splitNoteSource(source);
    final content = parts.content;
    final metadataSource = parts.metadata;
    final metadataSection = _sectionsOf(metadataSource).firstWhere(
      (section) => _sameKey(section.title, 'metadata'),
      orElse: () => const _MarkdownSection(title: 'Metadata'),
    );
    final metadata = _rowMap(metadataSection.rows);
    final records = <NoteRecord>[];
    final body = _bodyFromContent(content);
    final recordContent = _contentBeforeBody(content);
    final hasTemplate =
        _emptyToNull(metadata['template id']) != null ||
        _emptyToNull(metadata['template name']) != null;

    for (final section in _sectionsOf(recordContent)) {
      if (_sameKey(section.title, 'metadata')) {
        continue;
      }
      final values = <String, String>{};
      final headingRow = hasTemplate
          ? _MarkdownRow.tryParseHeading(section.title)
          : null;
      if (headingRow != null) {
        values[_normalizeKey(headingRow.key)] = headingRow.value.trim();
      }
      values.addAll(_rowMap(section.rows));
      final recordId = _emptyToNull(values.remove('record id'));
      records.add(
        NoteRecord(id: recordId, label: section.title, values: values),
      );
    }

    final fallbackId = p.basenameWithoutExtension(
      sourcePath ?? sanitizeFileName(title),
    );
    return Note(
      id: metadata['id'] ?? fallbackId,
      title: title,
      templateId: _emptyToNull(metadata['template id']),
      templateName: _emptyToNull(metadata['template name']),
      templateVersion: int.tryParse(metadata['template ver'] ?? '') ?? 0,
      icon: _emptyToNull(metadata['icon']),
      categoryPath: metadata['category'] ?? _categoryFromPath(sourcePath),
      tags: _splitCsv(metadata['tags']),
      records: records,
      body: body,
      isPinned: _parseBool(metadata['pinned']),
      isFavorite: _parseBool(metadata['favorite']),
      sourcePath: sourcePath,
      createdAt: _parseDate(metadata['created at']),
      updatedAt: _parseDate(metadata['updated at']) ?? updatedAt,
    );
  }

  static _NoteSourceParts _splitNoteSource(String source) {
    final lines = source.split('\n');
    for (var i = lines.length - 1; i >= 0; i -= 1) {
      if (lines[i].trim() == '---') {
        return _NoteSourceParts(
          content: lines.take(i).join('\n'),
          metadata: lines.skip(i + 1).join('\n'),
        );
      }
    }
    return _NoteSourceParts(content: source, metadata: '');
  }

  static String _contentBeforeBody(String content) {
    final lines = content.split('\n');
    final bodyIndex = _bodyHeadingIndex(lines);
    if (bodyIndex == null) {
      return content;
    }
    return lines.take(bodyIndex).join('\n');
  }

  static String _bodyFromContent(String content) {
    final lines = content.split('\n');
    final bodyIndex = _bodyHeadingIndex(lines);
    if (bodyIndex == null) {
      return '';
    }
    final bodyLines = lines.skip(bodyIndex + 1).toList();
    if (bodyLines.isNotEmpty && bodyLines.first.trim() == _bodySentinel) {
      bodyLines.removeAt(0);
    }
    return bodyLines.join('\n').trim();
  }

  static int? _bodyHeadingIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i += 1) {
      final title = _sectionHeadingTitle(lines[i]);
      if (title != null && _sameKey(title, 'body')) {
        return i;
      }
    }
    return null;
  }

  static _RecordHeading _headingForRecord(Note note, NoteRecord record) {
    final canDeriveFromFirstValue =
        (note.templateId != null || note.templateName != null) &&
        record.values.isNotEmpty;
    if (!canDeriveFromFirstValue) {
      return _RecordHeading(record.label);
    }
    final first = record.values.entries.first;
    final value = first.value.trim();
    if (value.isEmpty || value.contains('\n') || value.contains('\r')) {
      return _RecordHeading(record.label);
    }
    return _RecordHeading('${first.key}: $value', omittedValueKey: first.key);
  }

  static TemplateField _fieldFromSection(_MarkdownSection section) {
    final rows = _rowMap(section.rows);
    final typeValue = section.rows
        .where((row) => _sameKey(row.key, 'type'))
        .map((row) => row.value)
        .firstOrNull;
    final type = TemplateFieldType.parse(typeValue);
    final mode = rows['calendar mode'] ?? _secondaryDateType(section.rows);
    return TemplateField(
      id: rows['id'] ?? sanitizeFileName(section.title),
      label: section.title,
      type: type,
      isRequired: _parseBool(rows['required']),
      hint: _emptyToNull(rows['hint']),
      multiline: _parseBool(rows['multiline']),
      minLength: int.tryParse(rows['minlength'] ?? ''),
      maxLength: int.tryParse(rows['maxlength'] ?? ''),
      digits: int.tryParse(rows['digits'] ?? ''),
      min: num.tryParse(rows['min'] ?? ''),
      max: num.tryParse(rows['max'] ?? ''),
      options: _splitCsv(rows['options']),
      regex: _emptyToNull(rows['regex'] ?? rows['formula']),
      calendarMode: CalendarMode.parse(mode),
      primaryCalendar: CalendarSystem.parse(rows['primary']),
    );
  }

  static String _titleOf(String source) {
    final line = source
        .split('\n')
        .firstWhere(
          (candidate) => candidate.trimLeft().startsWith('# '),
          orElse: () => '# Untitled',
        );
    return line.replaceFirst(RegExp(r'^\s*#\s+'), '').trim();
  }

  static List<_MarkdownSection> _sectionsOf(String source) {
    final sections = <_MarkdownSection>[];
    String? title;
    final body = <String>[];
    for (final line in source.split('\n')) {
      final sectionTitle = _sectionHeadingTitle(line);
      if (sectionTitle != null) {
        if (title != null) {
          sections.add(
            _MarkdownSection(title: title, lines: List<String>.from(body)),
          );
        }
        title = sectionTitle;
        body.clear();
        continue;
      }
      if (title != null) {
        body.add(line);
      }
    }
    if (title != null) {
      sections.add(
        _MarkdownSection(title: title, lines: List<String>.from(body)),
      );
    }
    return sections;
  }

  static String? _sectionHeadingTitle(String line) {
    if (!line.startsWith('## ')) {
      return null;
    }
    return line.substring(3).trim();
  }

  static Map<String, String> _rowMap(List<_MarkdownRow> rows) {
    final values = <String, String>{};
    for (final row in rows) {
      values[_normalizeKey(row.key)] = row.value.trim();
    }
    return values;
  }

  static String? _secondaryDateType(List<_MarkdownRow> rows) {
    final typeRows = rows.where((row) => _sameKey(row.key, 'type')).toList();
    if (typeRows.length < 2) {
      return null;
    }
    return typeRows[1].value;
  }

  static List<String> _splitCsv(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const <String>[];
    }
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static bool _parseBool(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'true' || 'yes' || '1' => true,
      _ => false,
    };
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static String? _emptyToNull(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static String _categoryFromPath(String? sourcePath) {
    if (sourcePath == null || !sourcePath.startsWith('notes/')) {
      return '';
    }
    final directory = p.posix.dirname(sourcePath);
    return directory == 'notes' ? '' : directory.substring('notes/'.length);
  }

  static bool _sameKey(String a, String b) =>
      _normalizeKey(a) == _normalizeKey(b);

  static String _normalizeKey(String value) {
    return value
        .replaceAll('*', '')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static void _writeOptional(StringBuffer buffer, String key, Object? value) {
    if (value != null && value.toString().isNotEmpty) {
      buffer.writeln('- **$key**: $value');
    }
  }

  static void _writeRow(StringBuffer buffer, String key, Object? value) {
    final normalizedValue = (value ?? '')
        .toString()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = normalizedValue.split('\n');
    buffer.writeln('- **$key**: ${lines.first}');
    for (final line in lines.skip(1)) {
      buffer.writeln('  $line');
    }
  }
}

class _MarkdownSection {
  const _MarkdownSection({required this.title, this.lines = const <String>[]});

  final String title;
  final List<String> lines;

  String get rawBody => lines.join('\n');

  List<_MarkdownRow> get rows {
    return _MarkdownRow.parseLines(lines);
  }
}

class _MarkdownRow {
  const _MarkdownRow(this.key, this.value);

  final String key;
  final String value;

  static List<_MarkdownRow> parseLines(List<String> lines) {
    final rows = <_MarkdownRow>[];
    _MarkdownRow? current;
    final continuationLines = <String>[];

    void flushCurrent() {
      final row = current;
      if (row == null) {
        return;
      }
      rows.add(
        _MarkdownRow(
          row.key,
          <String>[row.value, ...continuationLines].join('\n').trim(),
        ),
      );
      current = null;
      continuationLines.clear();
    }

    for (final line in lines) {
      if (current != null && line.startsWith('  ')) {
        continuationLines.add(line.substring(2));
        continue;
      }
      final parsed = tryParse(line);
      if (parsed != null) {
        flushCurrent();
        current = parsed;
      }
    }
    flushCurrent();
    return rows;
  }

  static _MarkdownRow? tryParse(String line) {
    final match = RegExp(
      r'^\s*-\s+(?:\*\*)?([^:*]+?)(?:\*\*)?\s*:\s*(.*)$',
    ).firstMatch(line);
    if (match == null) {
      return null;
    }
    return _MarkdownRow(match.group(1)!.trim(), match.group(2)!.trim());
  }

  static _MarkdownRow? tryParseHeading(String heading) {
    final match = RegExp(r'^\s*([^:]+?)\s*:\s*(.+?)\s*$').firstMatch(heading);
    if (match == null) {
      return null;
    }
    return _MarkdownRow(match.group(1)!.trim(), match.group(2)!.trim());
  }
}

class _NoteSourceParts {
  const _NoteSourceParts({required this.content, required this.metadata});

  final String content;
  final String metadata;
}

class _RecordHeading {
  const _RecordHeading(this.title, {this.omittedValueKey});

  final String title;
  final String? omittedValueKey;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
