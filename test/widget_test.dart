import 'package:flutter_test/flutter_test.dart';
import 'package:organote/di/service_locator.dart';
import 'package:organote/services/storage/memory_file_store.dart';
import 'package:organote/ui/app_shell.dart';

void main() {
  testWidgets('app shell renders backend metrics', (tester) async {
    await getIt.reset();
    final store = MemoryFileStore();
    await store.initialize();
    await configureDependencies(fileStore: store);

    await tester.pumpWidget(const OrganoteApp());
    await tester.pump();

    expect(find.text('Organote'), findsWidgets);
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Compliance'), findsOneWidget);
  });
}
