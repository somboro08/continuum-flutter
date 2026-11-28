# Continuum navigation Flutter example

A small runnable Flutter app showing how to combine:

- `continuum_navigation_recovery` for router-neutral navigation snapshots;
- `continuum_navigation_flutter` for the declarative `Navigator.pages` adapter;
- `continuum_recovery` for recovery orchestration;
- `continuum_storage_file` for local durable storage.

## Run on Android or iOS

From this directory:

    flutter pub get
    flutter run

The example stores its snapshot in the app's application-support directory
using `path_provider` and `FileContinuumStore`. The file adapter is not
encrypted; this demo stores only a route ID and a non-sensitive example item
identifier. Never put passwords, OTPs, payment credentials or access tokens in
navigation parameters.

Open the detail page, then close and relaunch the app. The startup recovery
flow restores the last checkpointed navigation stack. This demonstrates
best-effort state restoration; it does not keep the process alive or guarantee
that the operating system will provide a final lifecycle callback.

## Test

    flutter test

The widget test uses `InMemoryContinuumStore` to verify navigation and
restoration without depending on a real process restart or filesystem.
