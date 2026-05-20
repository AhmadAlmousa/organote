import 'package:flutter_test/flutter_test.dart';
import 'package:organote/data/validation/field_validator.dart';
import 'package:organote/domain/models/models.dart';

void main() {
  group('FieldValidator', () {
    const validator = FieldValidator();

    test('reports required and number digit failures', () {
      const field = TemplateField(
        id: 'id',
        label: 'ID',
        type: TemplateFieldType.number,
        isRequired: true,
        digits: 10,
      );

      expect(
        validator.validateField(field, '').single.message,
        contains('required'),
      );
      expect(
        validator.validateField(field, '123').single.message,
        contains('10'),
      );
      expect(validator.validateField(field, '1234567890'), isEmpty);
    });

    test('validates URL, IP, regex, dropdown, and dual date fields', () {
      expect(
        validator.validateField(
          const TemplateField(
            id: 'url',
            label: 'URL',
            type: TemplateFieldType.url,
          ),
          'not a url',
        ),
        isNotEmpty,
      );
      expect(
        validator.validateField(
          const TemplateField(
            id: 'ip',
            label: 'IP',
            type: TemplateFieldType.ip,
          ),
          '192.168.1.10',
        ),
        isEmpty,
      );
      expect(
        validator.validateField(
          const TemplateField(
            id: 'rx',
            label: 'Regex',
            type: TemplateFieldType.regex,
            regex: r'^[A-Z]{2}\d{2}$',
          ),
          'AB12',
        ),
        isEmpty,
      );
      expect(
        validator.validateField(
          const TemplateField(
            id: 'dd',
            label: 'Dropdown',
            type: TemplateFieldType.dropdown,
            options: ['one', 'two'],
          ),
          'three',
        ),
        isNotEmpty,
      );
      expect(
        validator.validateField(
          const TemplateField(
            id: 'date',
            label: 'Date',
            type: TemplateFieldType.date,
            calendarMode: CalendarMode.dual,
          ),
          '01-01-2000 | 24-09-1420 H',
        ),
        isEmpty,
      );
    });

    test('enforces minLength and maxLength on text fields', () {
      const field = TemplateField(
        id: 'name',
        label: 'Name',
        type: TemplateFieldType.text,
        minLength: 3,
        maxLength: 5,
      );

      expect(
        validator.validateField(field, 'ab').single.message,
        contains('shorter'),
      );
      expect(
        validator.validateField(field, 'abcdef').single.message,
        contains('longer'),
      );
      expect(validator.validateField(field, 'abcd'), isEmpty);
    });

    test('enforces minLength and maxLength on password fields', () {
      const field = TemplateField(
        id: 'pwd',
        label: 'Password',
        type: TemplateFieldType.password,
        minLength: 4,
        maxLength: 8,
      );

      expect(
        validator.validateField(field, 'abc').single.message,
        contains('shorter'),
      );
      expect(
        validator.validateField(field, 'abcdefghi').single.message,
        contains('longer'),
      );
      expect(validator.validateField(field, 'secret'), isEmpty);
    });

    test('enforces number min/max range and rejects non-numeric input', () {
      const range = TemplateField(
        id: 'qty',
        label: 'Quantity',
        type: TemplateFieldType.number,
        min: 1,
        max: 10,
      );

      expect(
        validator.validateField(range, '0').single.message,
        contains('at least'),
      );
      expect(
        validator.validateField(range, '11').single.message,
        contains('at most'),
      );
      expect(validator.validateField(range, '5'), isEmpty);
      expect(
        validator.validateField(range, 'abc').single.message,
        contains('must be a number'),
      );
    });

    test('rejects non-digit input when digits is set', () {
      const field = TemplateField(
        id: 'sn',
        label: 'SN',
        type: TemplateFieldType.number,
        digits: 4,
      );

      expect(
        validator.validateField(field, '12.5').first.message,
        contains('digits only'),
      );
      expect(validator.validateField(field, '1234'), isEmpty);
    });

    test('validates gregorian-only and hijri-only date fields', () {
      const gregorian = TemplateField(
        id: 'g',
        label: 'G',
        type: TemplateFieldType.date,
        calendarMode: CalendarMode.gregorian,
      );
      const hijri = TemplateField(
        id: 'h',
        label: 'H',
        type: TemplateFieldType.date,
        calendarMode: CalendarMode.hijri,
      );

      expect(validator.validateField(gregorian, '01-01-2000'), isEmpty);
      expect(
        validator.validateField(gregorian, '01-01-2000 | 24-09-1420 H'),
        isNotEmpty,
      );
      expect(validator.validateField(hijri, '24-09-1420 H'), isEmpty);
      expect(validator.validateField(hijri, 'not a date'), isNotEmpty);
    });

    test('rejects malformed dual-date strings', () {
      const field = TemplateField(
        id: 'd',
        label: 'D',
        type: TemplateFieldType.date,
        calendarMode: CalendarMode.dual,
      );

      expect(validator.validateField(field, '01-01-2000'), isNotEmpty);
      expect(
        validator.validateField(field, '01-01-2000 | not-a-date'),
        isNotEmpty,
      );
    });

    test('validates boolean field with truthy and falsy synonyms', () {
      const field = TemplateField(
        id: 'flag',
        label: 'Flag',
        type: TemplateFieldType.boolean,
      );

      for (final ok in const ['true', 'False', 'YES', 'no', '1', '0']) {
        expect(validator.validateField(field, ok), isEmpty, reason: ok);
      }
      expect(
        validator.validateField(field, 'maybe').single.message,
        contains('true or false'),
      );
    });

    test(
      'allows free-form dropdown values when no options are configured',
      () {
        const field = TemplateField(
          id: 'free',
          label: 'Free',
          type: TemplateFieldType.dropdown,
        );

        expect(validator.validateField(field, 'anything'), isEmpty);
      },
    );

    test('rejects image references that escape the assets directory', () {
      const field = TemplateField(
        id: 'img',
        label: 'Image',
        type: TemplateFieldType.image,
      );

      expect(validator.validateField(field, 'assets/foo/bar.png'), isEmpty);
      expect(
        validator.validateField(field, '../escape.png').single.message,
        contains('relative asset path'),
      );
      expect(
        validator.validateField(field, '/etc/passwd').single.message,
        contains('relative asset path'),
      );
    });

    test('requires custom-label values to contain a colon separator', () {
      const field = TemplateField(
        id: 'cl',
        label: 'Custom',
        type: TemplateFieldType.customLabel,
      );

      expect(
        validator.validateField(field, 'just a value').single.message,
        contains('label and a value'),
      );
      expect(validator.validateField(field, 'vendor: Dell'), isEmpty);
    });

    test('skips type checks when an optional field is left blank', () {
      const optional = TemplateField(
        id: 'opt',
        label: 'Optional URL',
        type: TemplateFieldType.url,
      );

      expect(validator.validateField(optional, ''), isEmpty);
      expect(validator.validateField(optional, '   '), isEmpty);
    });

    test('validateRecord reads values by field label and by field id', () {
      const template = Template(
        id: 't',
        name: 'T',
        version: 1,
        fields: [
          TemplateField(
            id: 'name_field',
            label: 'Name',
            type: TemplateFieldType.text,
            isRequired: true,
          ),
          TemplateField(
            id: 'host',
            label: 'Hostname',
            type: TemplateFieldType.url,
            isRequired: true,
          ),
        ],
      );

      // 'Name' is keyed by label; 'host' is keyed by id (legacy/rename path).
      const record = NoteRecord(
        label: 'Record',
        values: {'Name': 'Ahmad', 'host': 'https://example.com'},
      );

      expect(validator.validateRecord(template, record), isEmpty);
    });
  });
}
