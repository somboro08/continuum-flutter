import 'package:continuum_navigation_flutter/continuum_navigation_flutter.dart';
import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NavigatorPagesAdapter', () {
    late NavigationPageRegistry registry;

    setUp(() {
      registry = NavigationPageRegistry({
        'home': (entry) => MaterialPage<void>(
              key: ValueKey<String>('home-${entry.parameters['id'] ?? 'root'}'),
              child: const SizedBox(),
            ),
        'details': (entry) => MaterialPage<void>(
              key: ValueKey<String>('details-${entry.parameters['id']}'),
              child: const SizedBox(),
            ),
      });
    });

    test('captures an immutable router-neutral stack', () async {
      final adapter = NavigatorPagesAdapter(
        pageRegistry: registry,
        initialEntries: [
          NavigationEntry(routeId: 'home'),
          NavigationEntry(routeId: 'details', parameters: {'id': '42'}),
        ],
      );

      final captured = await adapter.captureStack();

      expect(captured.map((entry) => entry.routeId), ['home', 'details']);
      expect(adapter.pages, hasLength(2));
      expect(() => captured.add(NavigationEntry(routeId: 'home')),
          throwsUnsupportedError);
      adapter.dispose();
    });

    test('replaces the full stack and notifies listeners once', () async {
      final adapter = NavigatorPagesAdapter(pageRegistry: registry);
      var notifications = 0;
      adapter.addListener(() => notifications++);

      await adapter.replaceStack([
        NavigationEntry(routeId: 'home'),
        NavigationEntry(routeId: 'details', parameters: {'id': '7'}),
      ]);

      expect(adapter.entries, hasLength(2));
      expect(adapter.pages, hasLength(2));
      expect(notifications, 1);
      adapter.dispose();
    });

    test('clears the stack and pages', () async {
      final adapter = NavigatorPagesAdapter(
        pageRegistry: registry,
        initialEntries: [NavigationEntry(routeId: 'home')],
      );

      await adapter.clearStack();

      expect(adapter.entries, isEmpty);
      expect(adapter.pages, isEmpty);
      adapter.dispose();
    });

    test('rejects a missing factory without changing current state', () async {
      final adapter = NavigatorPagesAdapter(
        pageRegistry: registry,
        initialEntries: [NavigationEntry(routeId: 'home')],
      );
      final oldPage = adapter.pages.single;

      await expectLater(
        adapter.replaceStack([NavigationEntry(routeId: 'missing')]),
        throwsA(isA<StateError>()),
      );

      expect(adapter.entries.single.routeId, 'home');
      expect(identical(adapter.pages.single, oldPage), isTrue);
      adapter.dispose();
    });

    test('factory errors do not partially replace the stack', () async {
      final failingRegistry = NavigationPageRegistry({
        'home': (_) => const MaterialPage<void>(
              key: ValueKey<String>('home'),
              child: SizedBox(),
            ),
        'broken': (_) => throw StateError('factory failed'),
      });
      final adapter = NavigatorPagesAdapter(
        pageRegistry: failingRegistry,
        initialEntries: [NavigationEntry(routeId: 'home')],
      );

      await expectLater(
        adapter.replaceStack([
          NavigationEntry(routeId: 'home'),
          NavigationEntry(routeId: 'broken'),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(adapter.entries, hasLength(1));
      expect(adapter.pages, hasLength(1));
      adapter.dispose();
    });

    test('rejects duplicate page keys before publishing a stack', () async {
      final duplicateRegistry = NavigationPageRegistry({
        'home': (_) => const MaterialPage<void>(
              key: ValueKey<String>('same'),
              child: SizedBox(),
            ),
        'details': (_) => const MaterialPage<void>(
              key: ValueKey<String>('same'),
              child: SizedBox(),
            ),
      });
      final adapter = NavigatorPagesAdapter(pageRegistry: duplicateRegistry);

      await expectLater(
        adapter.replaceStack([
          NavigationEntry(routeId: 'home'),
          NavigationEntry(routeId: 'details'),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(adapter.entries, isEmpty);
      expect(adapter.pages, isEmpty);
      adapter.dispose();
    });

    test('updates its stack when Navigator reports a removed page', () async {
      final adapter = NavigatorPagesAdapter(
        pageRegistry: registry,
        initialEntries: [
          NavigationEntry(routeId: 'home'),
          NavigationEntry(routeId: 'details', parameters: {'id': '9'}),
        ],
      );
      final removedPage = adapter.pages.last;

      expect(adapter.handlePageRemoved(removedPage), isTrue);
      expect(adapter.entries, hasLength(1));
      expect(adapter.entries.single.routeId, 'home');
      expect(adapter.pages, hasLength(1));
      expect(adapter.handlePageRemoved(removedPage), isFalse);
      adapter.dispose();
    });

    test('rejects operations after disposal', () async {
      final adapter = NavigatorPagesAdapter(pageRegistry: registry);
      adapter.dispose();

      await expectLater(adapter.captureStack(), throwsA(isA<StateError>()));
      await expectLater(adapter.clearStack(), throwsA(isA<StateError>()));
      await expectLater(
        adapter.replaceStack([NavigationEntry(routeId: 'home')]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
