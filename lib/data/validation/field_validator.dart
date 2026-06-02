import '../../domain/models/models.dart';
import '../../domain/util/image_field_values.dart';

class FieldValidationIssue {
  const FieldValidationIssue({required this.field, required this.message});

  final TemplateField field;
  final String message;
}

class FieldValidator {
  const FieldValidator();

  List<FieldValidationIssue> validateRecord(
    Template template,
    NoteRecord record,
  ) {
    return template.fields
        .expand(
          (field) => validateField(field, _fieldValue(record.values, field)),
        )
        .toList();
  }

  List<FieldValidationIssue> validateField(TemplateField field, String? value) {
    final normalized = value?.trim() ?? '';
    if (field.isRequired && normalized.isEmpty) {
      return <FieldValidationIssue>[
        FieldValidationIssue(
          field: field,
          message: '${field.label} is required.',
        ),
      ];
    }
    if (normalized.isEmpty) {
      return const <FieldValidationIssue>[];
    }

    final failures = <FieldValidationIssue>[];
    void fail(String message) {
      failures.add(FieldValidationIssue(field: field, message: message));
    }

    switch (field.type) {
      case TemplateFieldType.text:
      case TemplateFieldType.password:
        if (field.minLength != null && normalized.length < field.minLength!) {
          fail('${field.label} is shorter than ${field.minLength} characters.');
        }
        if (field.maxLength != null && normalized.length > field.maxLength!) {
          fail('${field.label} is longer than ${field.maxLength} characters.');
        }
      case TemplateFieldType.number:
        final parsed = num.tryParse(normalized);
        if (parsed == null) {
          fail('${field.label} must be a number.');
        } else {
          if (field.digits != null && !RegExp(r'^\d+$').hasMatch(normalized)) {
            fail('${field.label} must contain digits only.');
          }
          if (field.digits != null && normalized.length != field.digits) {
            fail('${field.label} must be ${field.digits} digits.');
          }
          if (field.min != null && parsed < field.min!) {
            fail('${field.label} must be at least ${field.min}.');
          }
          if (field.max != null && parsed > field.max!) {
            fail('${field.label} must be at most ${field.max}.');
          }
        }
      case TemplateFieldType.date:
        if (!_validDateValue(normalized, field.calendarMode)) {
          fail('${field.label} must match the configured date format.');
        }
      case TemplateFieldType.boolean:
        if (!const <String>{
          'true',
          'false',
          'yes',
          'no',
          '1',
          '0',
        }.contains(normalized.toLowerCase())) {
          fail('${field.label} must be true or false.');
        }
      case TemplateFieldType.dropdown:
        if (field.options.isNotEmpty && !field.options.contains(normalized)) {
          fail('${field.label} must be one of: ${field.options.join(', ')}.');
        }
      case TemplateFieldType.url:
        final uri = Uri.tryParse(normalized);
        if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
          fail('${field.label} must be a valid URL.');
        }
      case TemplateFieldType.ip:
        if (!_validIpAddress(normalized)) {
          fail('${field.label} must be a valid IPv4 address.');
        }
      case TemplateFieldType.regex:
        final pattern = field.regex;
        if (pattern != null && !RegExp(pattern).hasMatch(normalized)) {
          fail('${field.label} does not match the required pattern.');
        }
      case TemplateFieldType.image:
        final paths = parseImageFieldValue(normalized);
        if (paths.any((path) => path.contains('..') || path.startsWith('/'))) {
          fail('${field.label} must reference a relative asset path.');
        }
      case TemplateFieldType.customLabel:
        if (!normalized.contains(':')) {
          fail('${field.label} must include a label and a value.');
        }
    }

    return failures;
  }

  static bool _validIpAddress(String value) {
    final parts = value.split('.');
    if (parts.length != 4) {
      return false;
    }
    return parts.every((part) {
      final octet = int.tryParse(part);
      return octet != null && octet >= 0 && octet <= 255 && part == '$octet';
    });
  }

  static bool _validDateValue(String value, CalendarMode mode) {
    final parts = value.split('|').map((part) => part.trim()).toList();
    return switch (mode) {
      CalendarMode.dual => parts.length == 2 && parts.every(_looksLikeDate),
      CalendarMode.gregorian ||
      CalendarMode.hijri => parts.length == 1 && _looksLikeDate(parts[0]),
    };
  }

  static bool _looksLikeDate(String value) {
    return RegExp(r'^\d{1,4}[-/]\d{1,2}[-/]\d{1,4}(?:\s*H)?$').hasMatch(value);
  }

  static String? _fieldValue(Map<String, String> values, TemplateField field) {
    return values[field.label] ??
        values[field.id] ??
        values[_normalizedFieldKey(field.label)] ??
        values[_normalizedFieldKey(field.id)];
  }

  static String _normalizedFieldKey(String value) {
    return value
        .replaceAll('*', '')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
