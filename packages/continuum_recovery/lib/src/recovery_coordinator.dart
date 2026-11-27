import 'package:continuum_persistence/continuum_persistence.dart';
import 'recovery_participant.dart';

class RecoveryResult {
  const RecoveryResult({required this.restored, required this.missing, required this.failed});
  final List<String> restored;
  final List<String> missing;
  final Map<String, Object> failed;
}

/// Stores opaque feature snapshots; it does not interpret feature state.
class RecoveryCoordinator {
  RecoveryCoordinator({required ContinuumStore store, this.namespace = 'continuum.recovery'})
      : _store = store;

  final ContinuumStore _store;
  final String namespace;
  final Map<String, RecoveryParticipant> _participants = {};

  void register(RecoveryParticipant participant) {
    final id = participant.recoveryId.trim();
    if (id.isEmpty) throw ArgumentError.value(id, 'recoveryId', 'Must not be empty.');
    if (_participants.containsKey(id)) throw StateError('Participant "$id" already registered.');
    _participants[id] = participant;
  }

  Future<void> checkpoint() async {
    for (final participant in _participants.values) {
      final key = _key(participant.recoveryId);
      final snapshot = await participant.createSnapshot();
      if (snapshot == null) {
        await _store.delete(key);
      } else {
        await _store.write(key, snapshot);
      }
    }
  }

  Future<RecoveryResult> recover() async {
    final restored = <String>[];
    final missing = <String>[];
    final failed = <String, Object>{};
    for (final participant in _participants.values) {
      try {
        final snapshot = await _store.read(_key(participant.recoveryId));
        if (snapshot == null) {
          missing.add(participant.recoveryId);
        } else {
          await participant.restoreSnapshot(snapshot);
          restored.add(participant.recoveryId);
        }
      } catch (error) {
        failed[participant.recoveryId] = error;
      }
    }
    return RecoveryResult(restored: restored, missing: missing, failed: failed);
  }

  Future<void> clear(String recoveryId) async {
    final participant = _participants[recoveryId];
    if (participant != null) await participant.clearRecoveredState();
    await _store.delete(_key(recoveryId));
  }

  String _key(String id) => '$namespace.$id';
}
