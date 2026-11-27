import 'package:continuum_recovery/continuum_recovery.dart';

import 'draft_session.dart';
import 'draft_autosave_port.dart';

/// Batches dirty draft sessions through Continuum's shared checkpoint scheduler.
class DraftAutosaveController implements DraftAutosavePort {
  DraftAutosaveController({
    Duration debounce = const Duration(milliseconds: 400),
    Duration minimumInterval = const Duration(seconds: 2),
  }) {
    _scheduler = CheckpointScheduler(
      checkpoint: _checkpoint,
      debounce: debounce,
      minimumInterval: minimumInterval,
    );
  }

  late final CheckpointScheduler _scheduler;
  final Map<String, DraftSession> _sessions = <String, DraftSession>{};
  bool _disposed = false;
  Future<void>? _disposeFuture;

  bool get isDisposed => _disposed;
  int get registeredSessionCount => _sessions.length;

  void register(DraftSession session) {
    _ensureActive();
    if (_sessions.containsKey(session.formId)) {
      throw StateError('A draft session for "${session.formId}" is already registered.');
    }
    session.attachController(this);
    _sessions[session.formId] = session;
  }

  Future<bool> unregister(String formId, {bool flush = true}) async {
    _ensureActive();
    final session = _sessions[formId];
    if (session == null) return false;
    if (flush && session.isDirty) {
      final result = await checkpointNow();
      if (result.failed.containsKey(formId)) return false;
    }
    _sessions.remove(formId);
    session.detachController(this);
    return true;
  }

  Future<CheckpointResult> requestCheckpoint() {
    _ensureActive();
    return _scheduler.requestCheckpoint();
  }

  Future<CheckpointResult> checkpointNow() {
    _ensureActive();
    return _scheduler.checkpointNow();
  }

  Future<void> dispose({bool flushPending = true}) {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    _disposed = true;
    return _disposeFuture = _dispose(flushPending);
  }

  Future<void> _dispose(bool flushPending) async {
    if (flushPending && _sessions.values.any((session) => session.isDirty)) {
      await _scheduler.checkpointNow();
    }
    await _scheduler.dispose(flushPending: flushPending);
    for (final session in _sessions.values) {
      session.detachController(this);
    }
    _sessions.clear();
  }

  Future<CheckpointResult> _checkpoint() async {
    final saved = <String>[];
    final cleared = <String>[];
    final failed = <String, RecoveryFailure>{};

    for (final session in _sessions.values.toList()) {
      try {
        final result = await session.persistIfDirty();
        if (result == null) continue;
        if (result.cleared) {
          cleared.add(session.formId);
        } else {
          saved.add(session.formId);
        }
      } catch (error, stackTrace) {
        failed[session.formId] = RecoveryFailure(
          participantId: session.formId,
          stage: RecoveryStage.persist,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return CheckpointResult(saved: saved, cleared: cleared, failed: failed);
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('DraftAutosaveController has been disposed.');
    }
  }
}
