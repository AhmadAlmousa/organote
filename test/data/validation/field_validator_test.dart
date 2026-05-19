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
  });
}
