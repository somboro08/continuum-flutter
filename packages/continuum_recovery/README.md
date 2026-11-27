# continuum_recovery

Recovery primitives for applications built with Continuum. This package is platform-neutral and depends only on the storage contract.

## Feature-owned snapshots

Implement `RecoveryParticipant` for each feature. The feature controls its snapshot schema, validation and migration:

```dart
class SearchRecovery implements RecoveryParticipant {
  @override
  String get recoveryId => 'search';

  @override
  Future<String?> createSnapshot() async => serializeSearchState();

  @override
  Future<void> restoreSnapshot(String snapshot) async {
    restoreSearchState(snapshot);
  }

  @override
  Future<void> clearRecoveredState() async {
    clearSearchState();
  }
}
```

Register participants with `RecoveryCoordinator`. Checkpoint and recovery results report successful IDs and per-participant failures. A failing feature does not block unrelated participants.

## Checkpoint scheduling

```dart
final coordinator = RecoveryCoordinator(store: store)
  ..register(searchRecovery)
  ..register(formRecovery);

final scheduler = CheckpointScheduler(
  checkpoint: coordinator.checkpoint,
  debounce: const Duration(milliseconds: 400),
  minimumInterval: const Duration(seconds: 3),
);

// Call after state changes; nearby requests are coalesced.
await scheduler.requestCheckpoint();

// Explicit high-priority checkpoint, bypassing debounce and throttle.
await scheduler.checkpointNow();

// At controlled shutdown/disposal, optionally flush pending work.
await scheduler.dispose(flushPending: true);
```

Requests arriving while a checkpoint is running are retained for a subsequent checkpoint. Errors are propagated to every caller whose requests were coalesced into the failed run. The caller owns the coordinator, store and scheduler lifecycles.

## Important limitations

- This is not a guarantee that the operating system will keep an app or task alive.
- A checkpoint only persists the snapshot returned by a participant.
- Do not wait for a final lifecycle callback before saving important user work.
- The scheduler is not automatically connected to Flutter lifecycle events.
- Never persist secrets, OTPs or payment credentials through an unencrypted store.
