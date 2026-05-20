import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/services/compliance/compliance_service.dart';

void main() {
  group('ComplianceService', () {
    const service = ComplianceService();

    const serverV1 = Template(
      id: 'server',
      name: 'Server',
      version: 1,
      fields: <TemplateField>[
        TemplateField(
          id: 'host',
          label: 'Host Name',
          type: TemplateFieldType.text,
          isRequired: true,
        ),
        TemplateField(
          id: 'ip',
          label: 'IP Address',
          type: TemplateFieldType.ip,
        ),
      ],
    );

    Note noteWith({
      String id = 'n1',
      String title = 'Lab Box',
      String? templateId = 'server',
      String? templateName = 'Server',
      int templateVersion = 1,
      Map<String, String> values = const {
        'Host Name': 'nas-1',
        'IP Address': '192.168.0.1',
      },
    }) {
      return Note(
        id: id,
        title: title,
        templateId: templateId,
        templateName: templateName,
        templateVersion: templateVersion,
        records: <NoteRecord>[
          NoteRecord(label: 'Record', values: values),
        ],
      );
    }

    test('reports no issues for a clean note', () {
      final summary = service.scan(
        templates: const <Template>[serverV1],
        notes: <Note>[noteWith()],
      );

      expect(summary.issues, isEmpty);
      expect(summary.activeCount, 0);
      expect(summary.errorCount, 0);
    });

    test('flags missing required field as an error', () {
      final summary = service.scan(
        templates: const <Template>[serverV1],
        notes: <Note>[
          noteWith(values: const {'IP Address': '192.168.0.1'}),
        ],
      );

      final issue = summary.issues.singleWhere(
        (item) => item.type == ComplianceIssueType.missingRequiredField,
      );
      expect(issue.severity, ComplianceSeverity.error);
      expect(issue.fieldLabel, 'Host Name');
      expect(issue.message, contains('Host Name'));
      expect(summary.errorCount, greaterThanOrEqualTo(1));
    });

    test('flags type mismatches surfaced by the validator', () {
      final summary = service.scan(
        templates: const <Template>[serverV1],
        notes: <Note>[
          noteWith(values: const {
            'Host Name': 'nas-1',
            'IP Address': 'not.an.ip.address',
          }),
        ],
      );

      final issue = summary.issues.singleWhere(
        (item) => item.type == ComplianceIssueType.typeMismatch,
      );
      expect(issue.severity, ComplianceSeverity.error);
      expect(issue.fieldLabel, 'IP Address');
    });

    test('flags template version drift as a warning', () {
      const serverV2 = Template(
        id: 'server',
        name: 'Server',
        version: 2,
        fields: <TemplateField>[
          TemplateField(
            id: 'host',
            label: 'Host Name',
            type: TemplateFieldType.text,
            isRequired: true,
          ),
        ],
      );

      final summary = service.scan(
        templates: const <Template>[serverV2],
        notes: <Note>[
          noteWith(values: const {'Host Name': 'nas-1'}),
        ],
      );

      final issue = summary.issues.singleWhere(
        (item) => item.type == ComplianceIssueType.versionDrift,
      );
      expect(issue.severity, ComplianceSeverity.warning);
      expect(issue.message, contains('version 1'));
      expect(issue.message, contains('current is 2'));
    });

    test('flags orphan template refs when the template is gone', () {
      final summary = service.scan(
        templates: const <Template>[],
        notes: <Note>[
          noteWith(templateId: 'missing', templateName: 'Missing'),
        ],
      );

      final issue = summary.issues.singleWhere(
        (item) => item.type == ComplianceIssueType.orphanTemplateRef,
      );
      expect(issue.severity, ComplianceSeverity.error);
      expect(issue.message, contains('missing template'));
    });

    test('ignores notes that never referenced a template', () {
      final summary = service.scan(
        templates: const <Template>[],
        notes: <Note>[
          noteWith(templateId: null, templateName: null),
        ],
      );

      expect(summary.issues, isEmpty);
    });

    test('falls back to template lookup by name when id has drifted', () {
      const renamedTemplate = Template(
        id: 'server-renamed',
        name: 'Server',
        version: 1,
        fields: <TemplateField>[
          TemplateField(
            id: 'host',
            label: 'Host Name',
            type: TemplateFieldType.text,
            isRequired: true,
          ),
        ],
      );

      final summary = service.scan(
        templates: const <Template>[renamedTemplate],
        notes: <Note>[
          noteWith(
            templateId: 'server',
            templateName: 'Server',
            values: const {'Host Name': 'nas-1'},
          ),
        ],
      );

      expect(
        summary.issues.where(
          (issue) => issue.type == ComplianceIssueType.orphanTemplateRef,
        ),
        isEmpty,
      );
    });

    test(
      'suggests rename-copy when a field id matches a legacy record key',
      () {
        const renamedV2 = Template(
          id: 'server',
          name: 'Server',
          version: 2,
          fields: <TemplateField>[
            TemplateField(
              id: 'host-name',
              label: 'Hostname',
              type: TemplateFieldType.text,
            ),
          ],
        );

        final summary = service.scan(
          templates: const <Template>[renamedV2],
          notes: <Note>[
            noteWith(
              templateVersion: 2,
              values: const {'Host Name': 'nas-1'},
            ),
          ],
        );

        final suggestion = summary.issues.singleWhere(
          (issue) => issue.type == ComplianceIssueType.renameCopySuggestion,
        );
        expect(suggestion.severity, ComplianceSeverity.info);
        expect(suggestion.fieldLabel, 'Hostname');
        expect(suggestion.legacyFieldLabel, 'Host Name');
        expect(suggestion.message, contains('Hostname'));
      },
    );

    test(
      'suggests rename-copy when field words overlap a legacy record key',
      () {
        const renamedV2 = Template(
          id: 'server',
          name: 'Server',
          version: 2,
          fields: <TemplateField>[
            TemplateField(
              id: 'primary-host-name',
              label: 'Primary Host Name',
              type: TemplateFieldType.text,
            ),
          ],
        );

        final summary = service.scan(
          templates: const <Template>[renamedV2],
          notes: <Note>[
            noteWith(
              templateVersion: 2,
              values: const {'Hostname': 'nas-1'},
            ),
          ],
        );

        final suggestion = summary.issues.singleWhere(
          (issue) => issue.type == ComplianceIssueType.renameCopySuggestion,
        );
        expect(suggestion.legacyFieldLabel, 'Hostname');
      },
    );
  });
}
