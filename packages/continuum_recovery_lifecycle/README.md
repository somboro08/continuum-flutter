# continuum_recovery_lifecycle

Optional bridge between the platform-neutral lifecycle event contract and
Continuum's checkpoint scheduler. It does not depend on Flutter itself.

```dart
final scheduler = CheckpointScheduler(
  checkpoint: recoveryCoordinator.checkpoint,
);

final binding = LifecycleCheckpointBinding(
  lifecycle: lifecycleEventSource,
  scheduler: scheduler,
  onCheckpointResult: (result, transition) {
    // Inspect result.failed and report partial failures to diagnostics.
  },
  onCheckpointError: (error, stackTrace, transition) {
    // Report unexpected scheduler/store errors.
  },
);

binding.start();

// The app owns both objects and disposes them in dependency order.
await binding.dispose();
await scheduler.dispose(flushPending: true);
```

By default, hidden/paused/detached request checkpoints, while paused/detached
bypass debounce and throttling. These defaults are configurable. The binding
does not own the event source or scheduler and does not promise a final callback
before process termination.
