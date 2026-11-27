# Architecture

## Dependency rules
1. `continuum_core` contains platform-neutral contracts and module composition only.
2. Feature packages depend inward on core; core never imports feature packages.
3. Flutter, storage engines, routers, state managers and OS schedulers are adapters.
4. Applications opt into modules; no global singleton or implicit installation.
5. Features own their data schema, validation, migration and privacy policy.

## Package graph
```text
continuum_core
   ↑              ↑
lifecycle     persistence
                  ↑
               recovery
```

## Runtime
Modules declare stable IDs and dependencies. Continuum validates the dependency graph, initializes modules in dependency order, and disposes initialized modules in reverse order. A failed initialization triggers best-effort rollback.

## Recovery
Each feature implements `RecoveryParticipant` and serializes its own snapshot. `RecoveryCoordinator` stores opaque strings through `ContinuumStore`; it does not know about forms, navigation or app state.

Checkpoints are best-effort. Save at meaningful state changes and lifecycle transitions; never depend on a final callback before process death.

## Privacy and platform rules
Passwords, OTPs, secrets and payment credentials are not persisted by default. Sensitive persistence requires an explicit secure-storage strategy. Android/iOS remain authoritative for process lifetime, background execution, permissions and resource limits.

## Extension points
Navigation, drafts/forms, search history, operation journal, background scheduling, offline synchronization, keyboard/focus and feedback helpers should be independently installable packages or adapters. They must not add mandatory dependencies to core.
