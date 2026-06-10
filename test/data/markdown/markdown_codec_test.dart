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

    test(
      'characterizes generated note round trips for safe markdown shapes',
      () {
        for (final testCase in _generatedRoundTripNoteCases()) {
          final decoded = codec.decodeNote(codec.encodeNote(testCase.note));

          _expectRoundTripNote(decoded, testCase.note, reason: testCase.name);
        }
      },
    );

    test('preserves multiline record values on round trip', () {
      final note = Note(
        id: 'rt-multiline-value',
        title: 'Multiline Value',
        categoryPath: 'audit',
        records: const [
          NoteRecord(
            id: 'record-1',
            label: 'Record 1',
            values: {
              'description': 'line one\nline two\nline three',
              'status': 'active',
            },
          ),
        ],
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      _expectRoundTripNote(decoded, note, reason: 'CRITICAL-1');
    });

    test('preserves body headings on round trip', () {
      final note = Note(
        id: 'rt-body-headings',
        title: 'Body Headings',
        categoryPath: 'audit',
        records: const [],
        body: 'Intro.\n\n## Section A\nDetails.\n\n## Section B\nMore.',
      );

      final decoded = codec.decodeNote(codec.encodeNote(note));

      _expectRoundTripNote(decoded, note, reason: 'CRITICAL-2');
    });

    test(
      'decodes legacy body sections with markdown headings as body text',
      () {
        const source = '''
# Legacy Body

## Body
Intro.

## Section A
Details.

## Section B
More.

---

## Metadata
- **id**: legacy-body
- **category**: audit
''';

        final decoded = codec.decodeNote(source);

        expect(decoded.records, isEmpty);
        expect(
          decoded.body,
          'Intro.\n\n## Section A\nDetails.\n\n## Section B\nMore.',
        );
      },
    );

    test('uses first templated value as record heading', () {
      const note = Note(
        id: 'booklet-note',
        title: 'Booklets',
        templateId: 'booklet',
        templateName: 'Booklet',
        templateVersion: 1,
        records: [
          NoteRecord(
            label: 'Booklet 1',
            values: {'Person Name': 'John', 'ID': '123'},
          ),
        ],
      );

      final source = codec.encodeNote(note);
      final decoded = codec.decodeNote(source);

      expect(source, contains('## Person Name: John'));
      expect(source, isNot(contains('- **Person Name**: John')));
      expect(source, contains('- **ID**: 123'));
      expect(decoded.records.single.label, 'Person Name: John');
      expect(decoded.records.single.values['person name'], 'John');
      expect(decoded.records.single.values['id'], '123');
    });

    test('keeps freeform record labels and value bullets', () {
      const note = Note(
        id: 'freeform-record',
        title: 'Freeform',
        records: [
          NoteRecord(label: 'Record 1', values: {'Person Name': 'John'}),
        ],
      );

      final source = codec.encodeNote(note);

      expect(source, contains('## Record 1'));
      expect(source, contains('- **Person Name**: John'));
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

List<_RoundTripNoteCase> _generatedRoundTripNoteCases() {
  final bodyCases = <_RoundTripTextCase>[
    const _RoundTripTextCase('empty body', ''),
    const _RoundTripTextCase(
      'unicode body',
      'Arabic: \u0633\u0644\u0627\u0645. Emoji: \u{1F510}.',
    ),
    const _RoundTripTextCase(
      'body thematic break',
      'Intro paragraph.\n\n---\n\nAfter the break.',
    ),
  ];
  final valueCases = <_RoundTripValuesCase>[
    const _RoundTripValuesCase('plain values', {
      'name': 'Alpha',
      'url': 'https://example.test/a:b',
    }),
    const _RoundTripValuesCase('empty values', {'name': '', 'note': ''}),
    const _RoundTripValuesCase('unicode values', {
      'name': '\u0633\u0627\u0631\u0629',
      'symbol': '\u{1F510}',
    }),
  ];
  final cases = <_RoundTripNoteCase>[];

  for (var bodyIndex = 0; bodyIndex < bodyCases.length; bodyIndex += 1) {
    for (var valueIndex = 0; valueIndex < valueCases.length; valueIndex += 1) {
      final bodyCase = bodyCases[bodyIndex];
      final valueCase = valueCases[valueIndex];
      cases.add(
        _RoundTripNoteCase(
          '${bodyCase.name} + ${valueCase.name}',
          Note(
            id: 'rt-$bodyIndex-$valueIndex',
            title: 'Round Trip $bodyIndex $valueIndex',
            tags: const ['audit', 'round-trip'],
            categoryPath: 'audit/round-trip',
            body: bodyCase.text,
            records: [
              NoteRecord(
                id: 'record-$bodyIndex-$valueIndex',
                label: 'Record $bodyIndex $valueIndex',
                values: valueCase.values,
              ),
            ],
          ),
        ),
      );
    }
  }

  return cases;
}

void _expectRoundTripNote(
  Note actual,
  Note expected, {
  required String reason,
}) {
  expect(actual.id, expected.id, reason: '$reason id');
  expect(actual.title, expected.title, reason: '$reason title');
  expect(actual.templateId, expected.templateId, reason: '$reason templateId');
  expect(
    actual.templateName,
    expected.templateName,
    reason: '$reason templateName',
  );
  expect(
    actual.templateVersion,
    expected.templateVersion,
    reason: '$reason templateVersion',
  );
  expect(actual.icon, expected.icon, reason: '$reason icon');
  expect(actual.tags, expected.tags, reason: '$reason tags');
  expect(
    actual.categoryPath,
    expected.categoryPath,
    reason: '$reason category',
  );
  expect(actual.body, expected.body, reason: '$reason body');
  expect(actual.isPinned, expected.isPinned, reason: '$reason pinned');
  expect(actual.isFavorite, expected.isFavorite, reason: '$reason favorite');
  expect(actual.createdAt, expected.createdAt, reason: '$reason createdAt');
  expect(actual.updatedAt, expected.updatedAt, reason: '$reason updatedAt');
  expect(actual.records, hasLength(expected.records.length), reason: reason);

  for (var i = 0; i < expected.records.length; i += 1) {
    final actualRecord = actual.records[i];
    final expectedRecord = expected.records[i];
    expect(actualRecord.id, expectedRecord.id, reason: '$reason record[$i].id');
    expect(
      actualRecord.label,
      expectedRecord.label,
      reason: '$reason record[$i].label',
    );
    expect(
      actualRecord.values,
      expectedRecord.values,
      reason: '$reason record[$i].values',
    );
  }
}

class _RoundTripNoteCase {
  const _RoundTripNoteCase(this.name, this.note);

  final String name;
  final Note note;
}

class _RoundTripTextCase {
  const _RoundTripTextCase(this.name, this.text);

  final String name;
  final String text;
}

class _RoundTripValuesCase {
  const _RoundTripValuesCase(this.name, this.values);

  final String name;
  final Map<String, String> values;
}
