import 'package:continuum_navigation_go_router/continuum_navigation_go_router.dart';
import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('GoRouterNavigationAdapter', () {
    late GoRouter router;
    late List<NavigationEntry> currentEntries;
    late List<NavigationEntry>? writtenEntries;
    late bool cleared;

    setUp(() {
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox(),
          ),
        ],
      );
      currentEntries = [NavigationEntry(routeId: 'home')];
      writtenEntries = null;
      cleared = false;
    });

    tearDown(() {
      router.dispose();
    });

    GoRouterNavigationAdapter createAdapter() => GoRouterNavigationAdapter(
          router: router,
          readStack: (_) => currentEntries,
          writeStack: (_, entries) {
            writtenEntries = entries;
            currentEntries = entries;
          },
          clearStack: (_) {
            cleared = true;
            currentEntries = const [];
          },
        );

    test('captures a defensive immutable projection of the full stack',
        () async {
      final adapter = createAdapter();

      final result = await adapter.captureStack();

      expect(result.map((entry) => entry.routeId), ['home']);
      expect(
        () => result.add(NavigationEntry(routeId: 'details')),
        throwsUnsupportedError,
      );
      adapter.dispose();
    });

    test('passes an immutable complete stack to the application writer',
        () async {
      final adapter = createAdapter();
      final target = [
        NavigationEntry(routeId: 'home'),
        NavigationEntry(routeId: 'details', parameters: {'itemId': '42'}),
      ];

      await adapter.replaceStack(target);

      expect(writtenEntries, hasLength(2));
      expect(writtenEntries!.last.parameters['itemId'], '42');
      expect(
        () => writtenEntries!.add(NavigationEntry(routeId: 'other')),
        throwsUnsupportedError,
      );
      adapter.dispose();
    });

    test('delegates clear policy to the host application', () async {
      final adapter = createAdapter();

      await adapter.clearStack();

      expect(cleared, isTrue);
      expect(currentEntries, isEmpty);
      adapter.dispose();
    });

    test('propagates host mapping failures without hiding their cause',
        () async {
      final adapter = GoRouterNavigationAdapter(
        router: router,
        readStack: (_) => throw StateError('projection failed'),
        writeStack: (_, __) => throw StateError('restore failed'),
        clearStack: (_) => throw StateError('clear failed'),
      );

      await expectLater(
        adapter.captureStack(),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        adapter.replaceStack([NavigationEntry(routeId: 'home')]),
        throwsA(isA<StateError>()),
      );
      await expectLater(adapter.clearStack(), throwsA(isA<StateError>()));
      adapter.dispose();
    });

    test('rejects operations after disposal but leaves router ownership intact',
        () async {
      final adapter = createAdapter();
      adapter.dispose();

      await expectLater(adapter.captureStack(), throwsA(isA<StateError>()));
      await expectLater(adapter.clearStack(), throwsA(isA<StateError>()));
      await expectLater(
        adapter.replaceStack([NavigationEntry(routeId: 'home')]),
        throwsA(isA<StateError>()),
      );

      // The host still owns the router and can use its public API.
      expect(router.routerDelegate, isNotNull);
    });
  });
}
