import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/domain/repositories/repositories.dart';
import 'package:organote/ui/screens/template_builder/template_builder_screen.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:organote/ui/state/library_provider.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';
import 'package:organote/ui/theme/density.dart';

void main() {
  testWidgets('closes a root pane after saving a new template', (tester) async {
    final repo = _FakeTemplateRepo();

    await tester.pumpWidget(_TemplateBuilderRootHarness(repo: repo));

    await tester.enterText(
      find.widgetWithText(TextField, 'Template name'),
      'Server Login',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.savedInput?.name, 'Server Login');
    expect(find.text('New template'), findsNothing);
    expect(find.text('Closed server-login'), findsOneWidget);
  });
}

class _TemplateBuilderRootHarness extends StatefulWidget {
  const _TemplateBuilderRootHarness({required this.repo});

  final _FakeTemplateRepo repo;

  @override
  State<_TemplateBuilderRootHarness> createState() =>
      _TemplateBuilderRootHarnessState();
}

class _TemplateBuilderRootHarnessState
    extends State<_TemplateBuilderRootHarness> {
  bool _open = true;
  Template? _savedTemplate;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );

    return ProviderScope(
      overrides: [
        librarySnapshotProvider.overrideWithValue(const LibrarySnapshot()),
        templateRepositoryProvider.overrideWithValue(widget.repo),
      ],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: OrgDensity(
            level: OrgDensityLevel.comfortable,
            child: _open
                ? TemplateBuilderScreen(
                    onSaved: (template) {
                      setState(() => _savedTemplate = template);
                    },
                    onClose: () {
                      setState(() => _open = false);
                    },
                  )
                : Center(child: Text('Closed ${_savedTemplate?.id}')),
          ),
        ),
      ),
    );
  }
}

class _FakeTemplateRepo implements TemplateRepository {
  TemplateInput? savedInput;

  @override
  Future<void> deleteTemplate(String id) async {}

  @override
  Future<Template?> getTemplate(String id) async => null;

  @override
  Future<Template> saveTemplate(TemplateInput input) async {
    savedInput = input;
    return Template(
      id: 'server-login',
      name: input.name,
      version: input.version,
      icon: input.icon,
      defaultCategory: input.defaultCategory,
      layout: input.layout,
      fields: input.fields,
      updatedAt: DateTime.utc(2026, 5, 20),
    );
  }
}
