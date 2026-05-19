import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organote/di/service_locator.dart';
import 'package:organote/services/storage/memory_file_store.dart';
import 'package:organote/ui/organote_app.dart';
import 'package:organote/ui/state/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await getIt.reset();
    final store = MemoryFileStore();
    await store.initialize();
    await configureDependencies(fileStore: store);
  });

  testWidgets('Organote splash renders wordmark', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const OrganoteApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Organote'), findsAtLeastNWidgets(1));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
