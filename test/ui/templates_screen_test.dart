import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/ui/screens/templates/templates_screen.dart';
import 'package:organote/ui/state/library_provider.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';
import 'package:organote/ui/theme/density.dart';

void main() {
  testWidgets('TemplatesScreen groups templates by usage', (tester) async {
    final now = DateTime(2026, 5, 20, 10);
    final snapshot = LibrarySnapshot(
      templates: <Template>[
        Template(
          id: 'server-login',
          name: 'Server Login',
          version: 1,
          icon: 'S',
          updatedAt: now,
          fields: const <TemplateField>[
            TemplateField(
              id: 'host',
              label: 'Host',
              type: TemplateFieldType.ip,
              isRequired: true,
            ),
            TemplateField(
              id: 'password',
              label: 'Password',
              type: TemplateFieldType.password,
              isRequired: true,
            ),
          ],
        ),
        Template(
          id: 'project-brief',
          name: 'Project Brief',
          version: 1,
          fields: const <TemplateField>[
            TemplateField(
              id: 'summary',
              label: 'Summary',
              type: TemplateFieldType.text,
            ),
          ],
        ),
      ],
      notes: <Note>[
        Note(
          id: 'prod-db',
          title: 'Prod DB',
          templateId: 'server-login',
          templateName: 'Server Login',
          updatedAt: now,
          records: const <NoteRecord>[
            NoteRecord(label: 'Primary', values: <String, String>{}),
          ],
        ),
        Note(
          id: 'staging-db',
          title: 'Staging DB',
          templateId: 'server-login',
          templateName: 'Server Login',
          updatedAt: now.subtract(const Duration(hours: 1)),
          records: const <NoteRecord>[
            NoteRecord(label: 'Primary', values: <String, String>{}),
          ],
        ),
      ],
    );

    await tester.pumpWidget(_TemplateHarness(snapshot: snapshot));

    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Used templates'), findsOneWidget);
    expect(find.text('Unused templates'), findsOneWidget);
    expect(find.text('Server Login'), findsOneWidget);
    expect(find.text('Project Brief'), findsOneWidget);
    expect(find.text('2 notes'), findsOneWidget);

    await tester.ensureVisible(find.text('2 notes'));
    await tester.tap(find.text('2 notes'));
    await tester.pumpAndSettle();

    expect(find.text('2 associated notes'), findsOneWidget);
    expect(find.text('Prod DB'), findsOneWidget);
    expect(find.text('Staging DB'), findsOneWidget);
  });
}

class _TemplateHarness extends StatelessWidget {
  const _TemplateHarness({required this.snapshot});

  final LibrarySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );

    return ProviderScope(
      overrides: [librarySnapshotProvider.overrideWithValue(snapshot)],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: const OrgDensity(
            level: OrgDensityLevel.comfortable,
            child: TemplatesScreen(),
          ),
        ),
      ),
    );
  }
}
