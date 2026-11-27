# Architecture

## Dependency rules
1. `continuum_core` contains platform-neutral contracts and module composition only.
2. Flutter, storage engines, routers, state managers and OS schedulers are adapters.
3. Feature packages depend only on the contracts they actually use.
4. Core never imports a feature package; applications opt into modules explicitly.
5. Features own their data schema, validation, migration and privacy policy.

## Package graph
```text
continuum_core  ←  continuum_lifecycle

continuum_persistence  ←  continuum_recovery
```

These are intentionally separate dependency lines. The application composes them; no package needs to pull the entire framework into its dependency graph.

## Runtime
Modules declare stable IDs and dependencies. Continuum validates the dependency graph, initializes modules in dependency order, and disposes initialized modules in reverse order. A failed initialization triggers best-effort rollback, including cleanup of the module whose initialization failed.

## Storage adapters

`continuum_persistence` defines the storage port. `continuum_storage_file` is an optional Dart I/O adapter; applications choose its directory and must not use it for secrets because it does not encrypt values. Tests and ephemeral features can use `InMemoryContinuumStore`. `NamespacedContinuumStore` isolates a feature's keyspace without tying it to a storage engine.

## Recovery
Each feature implements `RecoveryParticipant` and serializes its own snapshot. `RecoveryCoordinator` stores opaque strings through `ContinuumStore`; it does not know about forms, navigation or app state.

Checkpoints are best-effort. Save at meaningful state changes and lifecycle transitions; never depend on a final callback before process death. A null snapshot deletes an older checkpoint so stale data cannot be restored accidentally.

## Privacy and platform rules
Passwords, OTPs, secrets and payment credentials are not persisted by default. Sensitive persistence requires an explicit secure-storage strategy. Android/iOS remain authoritative for process lifetime, background execution, permissions and resource limits.

## Extension points
Navigation, drafts/forms, search history, operation journal, background scheduling, offline synchronization, keyboard/focus and feedback helpers should be independently installable packages or adapters. They must not add mandatory dependencies to core.
