# continuum_navigation_flutter

Optional Flutter adapter that connects the router-neutral
`continuum_navigation_recovery` package to Flutter's declarative
`Navigator.pages` API. Requires Flutter 3.32 or newer because it uses
`Navigator.onDidRemovePage`.

## Why a separate package?

The recovery package owns serializable route IDs, parameter allow-lists,
validation and migrations. This package owns only the Flutter-specific
translation from a `NavigationEntry` to a `Page`. Neither package selects a
state-management library or makes Flutter's Navigator mandatory.

## Setup

Add both packages to the application:

    dependencies:
      continuum_navigation_recovery:
        path: ../continuum_navigation_recovery
      continuum_navigation_flutter:
        path: ../continuum_navigation_flutter

Register the pages your application knows how to build:

    final pageRegistry = NavigationPageRegistry({
      'home': (entry) => MaterialPage<void>(
            key: const ValueKey('home'),
            child: HomeScreen(),
          ),
      'order-details': (entry) => MaterialPage<void>(
            key: ValueKey('order-${entry.parameters['orderId']}'),
            child: OrderDetailsScreen(
              orderId: entry.parameters['orderId']! as String,
            ),
          ),
    });

Create the adapter and use it as the declarative source of truth for
`Navigator.pages`:

    final navigation = NavigatorPagesAdapter(pageRegistry: pageRegistry);

    AnimatedBuilder(
      animation: navigation,
      builder: (context, _) => Navigator(
        pages: navigation.pages,
        onDidRemovePage: navigation.handlePageRemoved,
      ),
    );

When the recovery participant calls `replaceStack`, the adapter first builds
and validates every target page. Only after all factories succeed does it
publish the new immutable stack and notify listeners. A failed factory,
unknown route, null key or duplicate page key leaves the previous stack
untouched.

## Connect recovery

The same adapter is passed to the router-neutral participant:

    final participant = NavigationRecoveryParticipant(
      recoveryId: 'app.navigation',
      state: navigation,
      routes: NavigationRouteRegistry([
        NavigationRouteDefinition(routeId: 'home'),
        NavigationRouteDefinition(
          routeId: 'order-details',
          persistedParameterKeys: {'orderId'},
        ),
      ]),
      schema: NavigationRecoverySchema(version: 1),
    );

The page registry and recovery route registry serve different purposes and
should be kept aligned by the application:

- `NavigationRouteRegistry` controls what may be persisted/restored.
- `NavigationPageRegistry` controls how a valid route becomes a Flutter page.

## Runnable example

See [example/README.md](example/README.md) for a complete Android/iOS app
using `FileContinuumStore`, `RecoveryCoordinator` and
`NavigationRecoveryParticipant`. Run it from the example directory with
`flutter pub get` and `flutter run`.

## Lifecycle and ownership

The application owns the adapter and must dispose it when no longer used.
The adapter does not own a `NavigatorState`, `GlobalKey`, `BuildContext`, or
route objects. It can be composed with any application-level state manager.

Use stable, unique page keys for every occurrence in a stack. If the same route
can appear more than once, include an occurrence or entity identifier in its
key. The adapter rejects null or duplicate keys before replacing the current
stack.

Keep parameters small and JSON-compatible. Persist only non-sensitive
identifiers that are explicitly allow-listed in the recovery route registry.
Never put passwords, OTPs, payment credentials, widgets, controllers, callbacks
or complete domain objects in navigation parameters.

`clearStack` publishes an empty page list. The host application decides what
empty navigation means for its product (for example, showing a signed-out shell
outside the Navigator).

This adapter uses Flutter's declarative Navigator API; it does not provide
GoRouter or AutoRoute adapters. Those can be implemented independently against
the same `NavigationStatePort` contract.
