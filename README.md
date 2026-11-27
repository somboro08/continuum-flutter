# Continuum

**A modular Flutter framework for resilient applications.**

Continuum helps Flutter applications preserve user progress, recover from interruptions, and coordinate resumable work without imposing a state-management or routing solution.

> An interruption should not mean losing progress.

## Design principles

- **OS priority:** Android and iOS remain in control of process and background execution.
- **Non-interference:** integrate with the host application's architecture instead of replacing it.
- **Graceful interruption:** persist useful checkpoints before an interruption whenever possible.
- **Recoverability:** restore only what can be safely and consistently restored.
- **Resource awareness:** adapt work to platform constraints, connectivity, and available resources.

Continuum does not promise to keep an application process alive. It provides explicit persistence and recovery mechanisms so an application can resume safely after recreation.

## Repository

This repository is a Dart/Flutter monorepo. Packages are intentionally separated by responsibility:

- `packages/continuum_core` — shared contracts, policies, capabilities and module lifecycle.
- `packages/continuum_lifecycle` — Flutter lifecycle observation.
- `packages/continuum_persistence` — storage abstractions and persistence policies.
- `packages/continuum_recovery` — recovery orchestration and checkpoints.
- `packages/continuum_drafts` — optional form-draft persistence, privacy filtering, autosave and schema migrations.
- `packages/continuum_navigation_recovery` — router-agnostic navigation stack recovery with route allow-lists and migrations.
- `packages/continuum_navigation_flutter` — optional Flutter Navigator.pages adapter for navigation recovery.

Additional modules (search history, operations, background tasks, offline sync, keyboard and feedback) will be added behind stable contracts.

## Compatibility goals

- No mandatory state-management library.
- No mandatory router.
- Storage engines are supplied through adapters.
- Platform-specific capabilities are isolated behind adapters.
- Modules can be used independently or composed through the core.

## Status

Early architecture and foundation phase. APIs are experimental until the first stable release.

## License

To be decided before the first public release.
