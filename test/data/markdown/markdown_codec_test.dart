import 'package:flutter_test/flutter_test.dart';
import 'package:organote/data/markdown/markdown_codec.dart';
import 'package:organote/domain/models/models.dart';

void main() {
  group('MarkdownCodec', () {
    const codec = MarkdownCodec();

    test('round trips templates with typed fields', () {
      final template = Template(
        id: 'family',
        name: 'Family Booklet',
        version: 2,
        icon: '*',
        defaultCategory: 'personal',
        layout: TemplateLayout.table,
        fields: const [
          TemplateField(
            id: 'name',
            label: 'Name',
            type: TemplateFieldType.text,
            isRequired: true,
            maxLength: 20,
          ),
          TemplateField(
            id: 'dob',
            label: 'DOB',
            type: TemplateFieldType.date,
            calendarMode: CalendarMode.dual,
            primaryCalendar: CalendarSystem.hijri,
          ),
          TemplateField(
            id: 'note',
            label: 'Custom Label',
            type: TemplateFieldType.customLabel,
          ),
        ],
      );

      final decoded = codec.decodeTemplate(codec.encodeTemplate(template));

      expect(decoded.id, 'family');
      expect(decoded.name, 'Family Booklet');
      expect(decoded.version, 2);
      expect(decoded.layout, TemplateLayout.table);
      expect(decoded.fields, hasLength(3));
      expect(decoded.fields[1].calendarMode, CalendarMode.dual);
      expect(decoded.fields[1].primaryCalendar, CalendarSystem.hijri);
      expect(decoded.fields[2].type, TemplateFieldType.customLabel);
    });

    test('round trips notes with multiple records, tags, and raw body', () {
      final note = Note(
        id: 'n1',
        title: 'Family',
        templateId: 'family',
        templateName: 'Family Booklet',
        templateVersion: 1,
        icon: '*',
        tags: const ['home', 'ids'],
        categoryPath: 'personal/docs',
        body: 'Freeform **markdown** body.',
        records: const [
          NoteRecord(label: 'Person-1', values: {'name': 'Ahmad', 'id': '123'}),
          NoteRecord(label: 'Person-2', values: {'name': 'Sarah', 'id': '456'}),
        ],
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      expect(decoded.id, 'n1');
      expect(decoded.title, 'Family');
      expect(decoded.tags, ['home', 'ids']);
      expect(decoded.categoryPath, 'personal/docs');
      expect(decoded.records, hasLength(2));
      expect(decoded.records.last.values['name'], 'Sarah');
      expect(decoded.body, 'Freeform **markdown** body.');
    });

    test('parses legacy sample date type rows without losing date type', () {
      const source = '''
# Template-Name-Goes-Here

## Metadata
- template name: sanitized-name-goes-here
- template ver: 1
- id: 123
- layout: cards

## DOB
- **type**: date
- **id**: 4
- **required**: true
- **hint**: Birth date
- **type**: dual
- **primary**: hijri
''';

      final template = codec.decodeTemplate(source);

      expect(template.fields.single.type, TemplateFieldType.date);
      expect(template.fields.single.calendarMode, CalendarMode.dual);
      expect(template.fields.single.primaryCalendar, CalendarSystem.hijri);
    });
  });
}
