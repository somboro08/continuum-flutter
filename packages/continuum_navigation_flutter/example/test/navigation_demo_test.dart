import 'package:continuum_navigation_flutter_example/main.dart';
import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigates, checkpoints and restores the details route',
      (tester) async {
    final store = InMemoryContinuumStore();
    final firstEnvironment = createExampleEnvironment(store: store);

    await tester.pumpWidget(
      ContinuumNavigationExampleApp(environment: firstEnvironment),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continuum Navigation'), findsOneWidget);

    await tester.tap(find.text('Voir le détail'));
    await tester.pumpAndSettle();

    expect(find.text('Détail restaurable'), findsOneWidget);
    expect(find.textContaining('demo-42'), findsOneWidget);

    // Simulate a newly created application environment using the same store.
    // This validates the recovery contract without relying on process survival.
    final restoredEnvironment = createExampleEnvironment(store: store);
    final result = await restoredEnvironment.recovery.recover();

    expect(result.restored, contains('demo.navigation'));
    expect(
      restoredEnvironment.navigation.entries.map((entry) => entry.routeId),
      ['home', 'details'],
    );

    await tester.pumpWidget(const SizedBox());
    firstEnvironment.dispose();
    restoredEnvironment.dispose();
  });
}
