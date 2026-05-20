import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/domain/models/models.dart';
import 'package:organote/ui/app/web_shell.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:organote/ui/state/library_provider.dart';
import 'package:organote/ui/theme/app_theme.dart';
import 'package:organote/ui/theme/color_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('WebShell shows dense list and content panes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final snapshot = _snapshot();

    await tester.pumpWidget(_WebShellHarness(prefs: prefs, snapshot: snapshot));
    await tester.pump();

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('2 visible / 2 total'), findsOneWidget);
    expect(find.text('Prod DB'), findsWidgets);
    expect(find.text('Tap any field to copy its value'), findsOneWidget);

    await tester.tap(find.byTooltip('Templates - Ctrl/Cmd+2'));
    await tester.pumpAndSettle();

    expect(find.text('Schemas'), findsOneWidget);
    expect(find.text('Server Login'), findsWidgets);
    expect(find.text('Fields'), findsOneWidget);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('Create note'), findsOneWidget);
  });

  testWidgets('WebShell supports desktop keyboard shortcuts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _WebShellHarness(prefs: prefs, snapshot: _snapshot()),
    );
    await tester.pump();

    expect(find.text('Notes'), findsOneWidget);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit2);
    await tester.pumpAndSettle();

    expect(find.text('Schemas'), findsOneWidget);
    expect(find.text('Server Login'), findsWidgets);

    await _pressControlShortcut(tester, LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();

    expect(find.text('New template'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('New template'), findsNothing);
    expect(find.text('Fields'), findsOneWidget);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit1);
    await tester.pumpAndSettle();

    expect(find.text('Notes'), findsOneWidget);

    await _pressControlShortcut(tester, LogicalKeyboardKey.keyK);
    await tester.pump();

    final noteSearch = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Search notes'),
    );
    expect(noteSearch.focusNode?.hasFocus, isTrue);

    await _pressControlShortcut(tester, LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Settings detail'), findsOneWidget);
  });
}

Future<void> _pressControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

LibrarySnapshot _snapshot() {
  final now = DateTime(2026, 5, 20, 10);
  const template = Template(
    id: 'server-login',
    name: 'Server Login',
    version: 1,
    icon: 'S',
    fields: <TemplateField>[
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
      ),
    ],
  );
  return LibrarySnapshot(
    categories: const <Category>[
      Category(path: 'servers', name: 'Servers', colorHex: '#31E6C2'),
    ],
    templates: const <Template>[template],
    notes: <Note>[
      Note(
        id: 'prod-db',
        title: 'Prod DB',
        templateId: template.id,
        templateName: template.name,
        categoryPath: 'servers',
        icon: 'P',
        updatedAt: now,
        records: const <NoteRecord>[
          NoteRecord(
            label: 'Primary',
            values: <String, String>{'Host': '10.0.0.1', 'Password': 'secret'},
          ),
        ],
      ),
      Note(
        id: 'stage-db',
        title: 'Stage DB',
        templateId: template.id,
        templateName: template.name,
        categoryPath: 'servers',
        updatedAt: now.subtract(const Duration(hours: 2)),
        records: const <NoteRecord>[
          NoteRecord(label: 'Primary', values: <String, String>{}),
        ],
      ),
    ],
  );
}

class _WebShellHarness extends StatelessWidget {
  const _WebShellHarness({required this.prefs, required this.snapshot});

  final SharedPreferences prefs;
  final LibrarySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final palette = OrgColors.palette(
      brightness: Brightness.dark,
      accentHue: OrgAccents.mint.hue,
    );
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySnapshotProvider.overrideWithValue(snapshot),
      ],
      child: OrgPaletteScope(
        palette: palette,
        child: MaterialApp(
          theme: OrgTheme.build(palette),
          home: const WebShell(
            home: SizedBox.shrink(),
            templates: SizedBox.shrink(),
            settings: Center(child: Text('Settings detail')),
          ),
        ),
      ),
    );
  }
}
