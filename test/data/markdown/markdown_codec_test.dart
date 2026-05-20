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

    test('round trips number, dropdown, url, ip, and regex field metadata', () {
      final template = Template(
        id: 'mixed',
        name: 'Mixed',
        version: 1,
        fields: const [
          TemplateField(
            id: 'qty',
            label: 'Qty',
            type: TemplateFieldType.number,
            min: 1,
            max: 99,
          ),
          TemplateField(
            id: 'env',
            label: 'Env',
            type: TemplateFieldType.dropdown,
            options: ['dev', 'staging', 'prod'],
          ),
          TemplateField(
            id: 'home',
            label: 'Homepage',
            type: TemplateFieldType.url,
          ),
          TemplateField(
            id: 'addr',
            label: 'Address',
            type: TemplateFieldType.ip,
          ),
          TemplateField(
            id: 'code',
            label: 'Code',
            type: TemplateFieldType.regex,
            regex: r'^[A-Z]{3}-\d{4}$',
          ),
        ],
      );

      final decoded = codec.decodeTemplate(codec.encodeTemplate(template));

      expect(decoded.fields, hasLength(5));
      expect(decoded.fields[0].min, 1);
      expect(decoded.fields[0].max, 99);
      expect(decoded.fields[1].options, ['dev', 'staging', 'prod']);
      expect(decoded.fields[2].type, TemplateFieldType.url);
      expect(decoded.fields[3].type, TemplateFieldType.ip);
      expect(decoded.fields[4].regex, r'^[A-Z]{3}-\d{4}$');
    });

    test('round trips notes with image references and pin/favorite flags', () {
      final note = Note(
        id: 'photos',
        title: 'Server Photos',
        templateId: 'rack',
        templateName: 'Rack',
        templateVersion: 1,
        records: const [
          NoteRecord(
            label: 'Rack-A',
            values: {
              'name': 'Lab-01',
              'photo': 'assets/server-photos/1700000000_rack.png',
            },
          ),
        ],
        isPinned: true,
        isFavorite: true,
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      expect(
        decoded.records.single.values['photo'],
        'assets/server-photos/1700000000_rack.png',
      );
      expect(decoded.isPinned, isTrue);
      expect(decoded.isFavorite, isTrue);
    });

    test('round trips custom-label records preserving order', () {
      final note = Note(
        id: 'srv',
        title: 'Servers',
        records: const [
          NoteRecord(
            label: 'Server-1',
            values: {'name': 'Home Lab', 'vendor': 'Dell'},
          ),
          NoteRecord(
            label: 'Server-2',
            values: {'name': 'Work Lab', 'serial': '1a2b3c'},
          ),
        ],
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      expect(decoded.records[0].values.keys.toList(), ['name', 'vendor']);
      expect(decoded.records[1].values.keys.toList(), ['name', 'serial']);
    });

    test('round trips body-only freeform notes without records', () {
      final note = Note(
        id: 'free',
        title: 'Free Thoughts',
        records: const [],
        body: 'Line one.\n\nLine two with **bold**.',
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      expect(decoded.records, isEmpty);
      expect(decoded.body, contains('Line one.'));
      expect(decoded.body, contains('**bold**'));
    });

    test('round trips category path and tag list on notes', () {
      final note = Note(
        id: 'cats',
        title: 'Tagged',
        categoryPath: 'work/clients/acme',
        tags: const ['priority', 'q4'],
        records: const [
          NoteRecord(label: 'Record', values: {'field': 'value'}),
        ],
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      expect(decoded.categoryPath, 'work/clients/acme');
      expect(decoded.tags, ['priority', 'q4']);
    });

    test(
      'derives category from sourcePath when metadata category is missing',
      () {
        const source = '''
# Sample

## Record-1
- **field**: value

---

## Metadata
- **id**: sample
''';

        final decoded = codec.decodeNote(
          source,
          sourcePath: 'notes/work/clients/sample.md',
        );

        expect(decoded.categoryPath, 'work/clients');
      },
    );

    test('decodes Untitled when no top-level heading is present', () {
      const source = '''
## Stray

- **field**: value
''';

      final decoded = codec.decodeNote(source);

      expect(decoded.title, 'Untitled');
      expect(decoded.records.single.values['field'], 'value');
    });
  });
}
