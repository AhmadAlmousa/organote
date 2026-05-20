import '../../data/validation/field_validator.dart';
import '../../domain/models/models.dart';

class ComplianceService {
  const ComplianceService({FieldValidator validator = const FieldValidator()})
    : _validator = validator;

  final FieldValidator _validator;

  ComplianceSummary scan({
    required List<Template> templates,
    required List<Note> notes,
    Set<String> ignoredIssueIds = const <String>{},
  }) {
    final templateById = {
      for (final template in templates) template.id: template,
    };
    final templateByName = {
      for (final template in templates) template.name.toLowerCase(): template,
    };
    final issues = <ComplianceIssue>[];

    for (final note in notes) {
      final template = note.templateId == null
          ? null
          : templateById[note.templateId!] ??
                templateByName[note.templateName?.toLowerCase() ?? ''];
      if (template == null) {
        if (note.templateId != null || note.templateName != null) {
          issues.add(
            ComplianceIssue(
              id: '${note.id}:orphan-template',
              type: ComplianceIssueType.orphanTemplateRef,
              severity: ComplianceSeverity.error,
              noteId: note.id,
              templateId: note.templateId,
              message: 'Note "${note.title}" references a missing template.',
            ),
          );
        }
        continue;
      }

      if (note.templateVersion != template.version) {
        issues.add(
          ComplianceIssue(
            id: '${note.id}:version',
            type: ComplianceIssueType.versionDrift,
            severity: ComplianceSeverity.warning,
            noteId: note.id,
            templateId: template.id,
            message:
                'Note "${note.title}" uses template version ${note.templateVersion}; current is ${template.version}.',
          ),
        );
      }

      for (final record in note.records) {
        final normalizedRecordKeys = {
          for (final key in record.values.keys) _normalize(key): key,
        };
        for (final field in template.fields) {
          final value = record.values[field.label] ?? record.values[field.id];
          if (field.isRequired && (value == null || value.trim().isEmpty)) {
            issues.add(
              ComplianceIssue(
                id: '${note.id}:${record.label}:${field.id}:missing',
                type: ComplianceIssueType.missingRequiredField,
                severity: ComplianceSeverity.error,
                noteId: note.id,
                templateId: template.id,
                fieldLabel: field.label,
                message:
                    'Record "${record.label}" is missing required field "${field.label}".',
              ),
            );
          }
          for (final validationIssue in _validator.validateField(
            field,
            value,
          )) {
            issues.add(
              ComplianceIssue(
                id: '${note.id}:${record.label}:${field.id}:type',
                type: ComplianceIssueType.typeMismatch,
                severity: ComplianceSeverity.error,
                noteId: note.id,
                templateId: template.id,
                fieldLabel: field.label,
                message: validationIssue.message,
              ),
            );
          }
          if (value == null) {
            final likelyLegacyKey = _findLikelyLegacyKey(
              field,
              normalizedRecordKeys,
            );
            if (likelyLegacyKey != null) {
              issues.add(
                ComplianceIssue(
                  id: '${note.id}:${record.label}:${field.id}:rename',
                  type: ComplianceIssueType.renameCopySuggestion,
                  severity: ComplianceSeverity.info,
                  noteId: note.id,
                  templateId: template.id,
                  fieldLabel: field.label,
                  legacyFieldLabel: likelyLegacyKey,
                  message:
                      'Copy "$likelyLegacyKey" into renamed field "${field.label}" if it is the same data.',
                ),
              );
            }
          }
        }
      }
    }

    if (ignoredIssueIds.isEmpty) {
      return ComplianceSummary(issues: issues);
    }
    return ComplianceSummary(
      issues: [
        for (final issue in issues)
          if (ignoredIssueIds.contains(issue.id))
            ComplianceIssue(
              id: issue.id,
              type: issue.type,
              severity: issue.severity,
              message: issue.message,
              noteId: issue.noteId,
              templateId: issue.templateId,
              fieldLabel: issue.fieldLabel,
              legacyFieldLabel: issue.legacyFieldLabel,
              ignored: true,
            )
          else
            issue,
      ],
    );
  }

  static String? _findLikelyLegacyKey(
    TemplateField field,
    Map<String, String> normalizedRecordKeys,
  ) {
    final fieldWords = _normalize(
      field.label,
    ).split(' ').where((word) => word.length > 2);
    for (final entry in normalizedRecordKeys.entries) {
      if (entry.key == _normalize(field.id)) {
        return entry.value;
      }
      if (fieldWords.any(entry.key.contains)) {
        return entry.value;
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
