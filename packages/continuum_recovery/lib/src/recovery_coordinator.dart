import 'dart:async';
import 'package:continuum_persistence/continuum_persistence.dart';
import 'recovery_participant.dart';

enum RecoveryStage { snapshot, persist, read, restore, clear }

class RecoveryFailure {
  const RecoveryFailure({required this.participantId, required this.stage, required this.error, required this.stackTrace});
  final String participantId;
  final RecoveryStage stage;
  final Object error;
  final StackTrace stackTrace;
  @override
  String toString() => 'RecoveryFailure($participantId, ${stage.name}): $error';
}

class CheckpointResult {
  const CheckpointResult({required this.saved, required this.cleared, required this.failed});
  final List<String> saved;
  final List<String> cleared;
  final Map<String, RecoveryFailure> failed;
  bool get isSuccessful => failed.isEmpty;
}

class RecoveryResult {
  const RecoveryResult({required this.restored, required this.missing, required this.failed});
  final List<String> restored;
  final List<String> missing;
  final Map<String, RecoveryFailure> failed;
  bool get isSuccessful => failed.isEmpty;
}

/// Coordinates opaque feature-owned snapshots. Operations are serialized to
/// prevent checkpoint/restore/clear races. One participant failure never
/// blocks other participants from being processed.
class RecoveryCoordinator {
  RecoveryCoordinator({required ContinuumStore store, this.namespace = 'continuum.recovery'}) : _store = store {
    validateStorageKey(namespace, parameterName: 'namespace');
  }
  final ContinuumStore _store;
  final String namespace;
  final Map<String, RecoveryParticipant> _participants = <String, RecoveryParticipant>{};
  Future<void> _operationTail = Future<void>.value();

  void register(RecoveryParticipant participant) {
    final id = participant.recoveryId.trim();
    validateStorageKey(id, parameterName: 'recoveryId');
    if (_participants.containsKey(id)) throw StateError('Participant "$id" is already registered.');
    _participants[id] = participant;
  }

  bool unregister(String recoveryId) => _participants.remove(recoveryId) != null;

  Future<CheckpointResult> checkpoint() => _exclusive(() async {
    final saved = <String>[];
    final cleared = <String>[];
    final failed = <String, RecoveryFailure>{};
    for (final participant in _participants.values.toList()) {
      final id = participant.recoveryId;
      String? snapshot;
      try {
        snapshot = await participant.createSnapshot();
      } catch (error, stackTrace) {
        failed[id] = RecoveryFailure(participantId: id, stage: RecoveryStage.snapshot, error: error, stackTrace: stackTrace);
        continue;
      }
      try {
        if (snapshot == null) {
          await _store.delete(_key(id));
          cleared.add(id);
        } else {
          await _store.write(_key(id), snapshot);
          saved.add(id);
        }
      } catch (error, stackTrace) {
        failed[id] = RecoveryFailure(participantId: id, stage: RecoveryStage.persist, error: error, stackTrace: stackTrace);
      }
    }
    return CheckpointResult(saved: saved, cleared: cleared, failed: failed);
  });

  Future<RecoveryResult> recover() => _exclusive(() async {
    final restored = <String>[];
    final missing = <String>[];
    final failed = <String, RecoveryFailure>{};
    for (final participant in _participants.values.toList()) {
      final id = participant.recoveryId;
      String? snapshot;
      try {
        snapshot = await _store.read(_key(id));
      } catch (error, stackTrace) {
        failed[id] = RecoveryFailure(participantId: id, stage: RecoveryStage.read, error: error, stackTrace: stackTrace);
        continue;
      }
      if (snapshot == null) {
        missing.add(id);
        continue;
      }
      try {
        await participant.restoreSnapshot(snapshot);
        restored.add(id);
      } catch (error, stackTrace) {
        failed[id] = RecoveryFailure(participantId: id, stage: RecoveryStage.restore, error: error, stackTrace: stackTrace);
      }
    }
    return RecoveryResult(restored: restored, missing: missing, failed: failed);
  });

  Future<void> clear(String recoveryId) => _exclusive(() async {
    validateStorageKey(recoveryId, parameterName: 'recoveryId');
    final participant = _participants[recoveryId];
    if (participant != null) await participant.clearRecoveredState();
    await _store.delete(_key(recoveryId));
  });

  String _key(String id) => '$namespace.$id';

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
