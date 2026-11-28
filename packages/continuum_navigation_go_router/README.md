# continuum_navigation_go_router

Optional GoRouter bridge for `continuum_navigation_recovery`. It keeps the
GoRouter dependency isolated from Continuum's recovery contracts and from the
Flutter `Navigator.pages` adapter.

## Why the application supplies the stack mapping

GoRouter supports nested route trees, `ShellRoute`, `StatefulShellRoute`,
imperative pushes, redirects and guards. These do not have one universal
mapping to a linear list of Continuum route entries. Reading private/internal
route-match state or persisting `GoRouterState.extra` would make recovery
fragile and could accidentally serialize application objects.

Therefore this adapter uses public GoRouter ownership and explicit application
callbacks:

- `readStack` projects the application's complete logical stack into
  `NavigationEntry` values.
- `writeStack` validates/resolves the complete target and rebuilds navigation
  using the application's route definitions and public GoRouter APIs.
- `clearStack` applies the application's chosen empty-stack/sign-out policy.

The reader must return the complete logical stack, not only the visible page.
The writer owns the mapping for nested routes, shell branches, route parameters,
redirects and guards. It should validate all entries before navigating.

## Setup

Add the optional package alongside the router-neutral recovery package:

    dependencies:
      go_router: ^16.2.5
      continuum_navigation_recovery:
        path: ../continuum_navigation_recovery
      continuum_navigation_go_router:
        path: ../continuum_navigation_go_router

Create the adapter using your application's route model:

    final navigationPort = GoRouterNavigationAdapter(
      router: router,
      readStack: (router) => appNavigationState.toContinuumEntries(),
      writeStack: (router, entries) async {
        final target = appNavigationState.resolve(entries);
        // Use the app's route table and public GoRouter APIs here.
        await appNavigationState.navigateTo(router, target);
      },
      clearStack: (router) => router.go('/'),
    );

Then pass `navigationPort` to `NavigationRecoveryParticipant` as its
`state` argument. The recovery participant continues to enforce route
allow-lists, parameter filtering, validation and migrations.

## Important guarantees and limitations

- The adapter copies entries and exposes immutable lists to callbacks.
- It propagates application mapping and navigation errors unchanged.
- It never serializes GoRouter internals, widgets, BuildContexts, callbacks or
  `extra` objects.
- It does not own or dispose the GoRouter instance.
- The host application owns the route mapping and complete-stack projection.
- GoRouter redirects, guards, asynchronous resolution and nested shell behavior
  can make a navigation transition fail or produce a different destination.
  Atomic rollback is the application's responsibility; this adapter does not
  claim that GoRouter can replace every arbitrary stack atomically.
- Persist only small, non-sensitive, JSON-compatible identifiers explicitly
  allow-listed by `NavigationRouteRegistry`.

This package is intentionally a bridge rather than a second router abstraction.
Applications that need direct declarative page ownership can use
`continuum_navigation_flutter` instead.
