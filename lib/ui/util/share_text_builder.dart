import '../../domain/models/models.dart';

String buildShareText(Note note, {Template? template}) {
  final buffer = StringBuffer();
  final title = note.title.isEmpty ? 'Untitled' : note.title;
  buffer.writeln(title);
  buffer.writeln('=' * title.length);
  buffer.writeln();

  if (note.records.isEmpty && note.body.trim().isEmpty) {
    buffer.writeln('(empty note)');
    return buffer.toString().trim();
  }

  for (var index = 0; index < note.records.length; index += 1) {
    final record = note.records[index];
    final heading = record.label.isEmpty ? 'Record ${index + 1}' : record.label;
    buffer.writeln(heading);
    buffer.writeln('-' * heading.length);

    final orderedKeys = <String>[];
    if (template != null) {
      for (final field in template.fields) {
        if (record.values.containsKey(field.label)) {
          orderedKeys.add(field.label);
        } else if (record.values.containsKey(field.id)) {
          orderedKeys.add(field.id);
        }
      }
    }
    for (final key in record.values.keys) {
      if (!orderedKeys.contains(key)) orderedKeys.add(key);
    }

    for (final key in orderedKeys) {
      final value = record.values[key] ?? '';
      if (value.isEmpty) continue;
      buffer.writeln('$key: $value');
    }
    buffer.writeln();
  }

  if (note.body.trim().isNotEmpty) {
    buffer.writeln(note.body.trim());
    buffer.writeln();
  }

  if (note.tags.isNotEmpty) {
    buffer.writeln('Tags: ${note.tags.map((t) => '#$t').join(' ')}');
  }

  return buffer.toString().trim();
}
