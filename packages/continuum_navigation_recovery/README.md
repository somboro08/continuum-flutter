# continuum_navigation_recovery

Router-agnostic navigation stack recovery for Continuum. This package has no Flutter or router dependency. The host application implements **NavigationStatePort** to connect its router to the recovery contracts.

## Basic setup

~~~dart
final routes = NavigationRouteRegistry([
  NavigationRouteDefinition(routeId: 'home'),
  NavigationRouteDefinition(
    routeId: 'profile',
    persistedParameterKeys: {'userId', 'tab'},
    validateParameters: (params) =>
        params['userId'] is String &&
        (params['tab'] == null || params['tab'] is String),
  ),
  NavigationRouteDefinition(
    routeId: 'login',
    canRestore: false,
  ),
]);

final navigation = NavigationRecoveryParticipant(
  recoveryId: 'app.navigation',
  state: myNavigationAdapter,
  routes: routes,
  schema: NavigationRecoverySchema(version: 1),
);

final coordinator = RecoveryCoordinator(store: store);
coordinator.register(navigation);

// At startup, after the router adapter is ready:
final result = await coordinator.recover();
if (!result.isSuccessful) {
  // Inspect result.failed['app.navigation'].
}

// Checkpoint on meaningful navigation changes or through the shared
// CheckpointScheduler/lifecycle bridge.
final checkpoint = await coordinator.checkpoint();
~~~

## Safety and privacy

- Only registered routes are eligible for restoration.
- A route with `canRestore: false` prevents the entire current stack from being persisted. This avoids saving a misleading partial stack when authentication or another transient screen is present.
- Route parameters are empty by default. Explicitly allow-list small, non-sensitive keys with `persistedParameterKeys`.
- Optional validators run on capture and restore.
- Unknown routes, unapproved parameter keys, invalid values and future schema versions are rejected before the adapter is asked to replace the stack.
- Never persist access tokens, passwords, OTPs, payment data, or full domain objects in route parameters.

## Schema migrations

Increment `NavigationRecoverySchema.version` when the persisted navigation representation changes. Supply sequential `NavigationMigration` functions for each supported version transition. Migrations operate on immutable entry lists. Missing migrations and failed migrations produce typed errors; the package does not silently discard an old stack.

## Router integration contract

Implement `NavigationStatePort` in the host application. `replaceStack` should construct and validate the complete target stack before changing visible navigation, so a failed restore cannot leave the UI partially navigated. The adapter owns router-specific behavior, route construction and any platform restoration details.

The participant implements Continuum's `RecoveryParticipant` and can be registered with the existing `RecoveryCoordinator`. The coordinator remains responsible for persistence, serialization of recovery operations and checkpoint orchestration.
