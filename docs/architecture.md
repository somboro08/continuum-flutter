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
continuum_persistence + continuum_recovery  ←  continuum_drafts
continuum_recovery  ←  continuum_navigation_recovery

continuum_persistence  ←  continuum_storage_file

continuum_core + continuum_recovery  ←  continuum_recovery_lifecycle
```

These are intentionally separate dependency lines. The application composes them; no package needs to pull the entire framework into its dependency graph.

## Runtime
Modules declare stable IDs and dependencies. Continuum validates the dependency graph, initializes modules in dependency order, and disposes initialized modules in reverse order. A failed initialization triggers best-effort rollback, including cleanup of the module whose initialization failed.

## Storage adapters
`continuum_persistence` defines the storage port. `continuum_storage_file` is an optional Dart I/O adapter; applications choose its directory and must not use it for secrets because it does not encrypt values. Tests and ephemeral features can use `InMemoryContinuumStore`. `NamespacedContinuumStore` isolates a feature's keyspace without tying it to a storage engine.

## Recovery and checkpoints
Each feature implements `RecoveryParticipant` and serializes its own snapshot. `RecoveryCoordinator` stores opaque strings through `ContinuumStore`; it does not know about forms, navigation or app state.

`CheckpointScheduler` coalesces nearby checkpoint requests with a debounce window and enforces a minimum interval between automatic runs. Explicit checkpoints bypass both limits. Requests arriving during an active checkpoint are queued for a later snapshot; they are never incorrectly completed by an older snapshot. Disposal can flush pending work and waits for all queued checkpoints.

Checkpoints are best-effort. Save at meaningful state changes and lifecycle transitions; never depend on a final callback before process death. A null snapshot deletes an older checkpoint so stale data cannot be restored accidentally. The scheduler does not subscribe to lifecycle events itself. The optional `continuum_recovery_lifecycle` package bridges the platform-neutral `LifecycleEventSource` to the scheduler. By default, hidden/paused/detached request checkpoints and paused/detached bypass debounce and throttling. The binding does not own the source or scheduler; applications control disposal order.

## Privacy and platform rules
Passwords, OTPs, secrets and payment credentials are not persisted by default. Sensitive persistence requires an explicit secure-storage strategy. Android/iOS remain authoritative for process lifetime, background execution, permissions and resource limits.

## Extension points
Draft/form recovery is provided by the optional `continuum_drafts` package. It uses the storage port and shared checkpoint scheduler, keeps schema and migration ownership with each form, and filters fields through an explicit privacy policy. Search history, operation journal, background scheduling, offline synchronization, keyboard/focus and feedback helpers should likewise be independently installable packages or adapters.

Navigation recovery is provided by the optional `continuum_navigation_recovery` package. It implements `RecoveryParticipant`, stores router-neutral route IDs and explicitly allow-listed parameters, validates the complete stack before restore, and delegates router operations to an application-owned `NavigationStatePort`. It does not depend on or select a routing library. They must not add mandatory dependencies to core.
