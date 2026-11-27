import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:continuum_recovery/continuum_recovery.dart';
import 'package:test/test.dart';

class _MemoryStore implements ContinuumStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<void> delete(String key) async { values.remove(key); }
  @override
  Future<void> deleteAll({String? namespace}) async { values.clear(); }
}

class _Participant implements RecoveryParticipant {
  @override
  String get recoveryId => 'editor';
  String? snapshot = 'draft-v1';
  String? restored;
  bool cleared = false;
  @override
  Future<String?> createSnapshot() async => snapshot;
  @override
  Future<void> restoreSnapshot(String value) async { restored = value; }
  @override
  Future<void> clearRecoveredState() async { cleared = true; }
}

void main() {
  test('checkpoints and restores feature-owned snapshots', () async {
    final store = _MemoryStore();
    final participant = _Participant();
    final coordinator = RecoveryCoordinator(store: store);
    coordinator.register(participant);
    await coordinator.checkpoint();
    participant.restored = null;

    final result = await coordinator.recover();
    expect(participant.restored, 'draft-v1');
    expect(result.restored, ['editor']);
    expect(result.failed, isEmpty);
  });

  test('a null checkpoint removes stale data', () async {
    final store = _MemoryStore();
    final participant = _Participant();
    final coordinator = RecoveryCoordinator(store: store);
    coordinator.register(participant);
    await coordinator.checkpoint();
    participant.snapshot = null;
    await coordinator.checkpoint();

    final result = await coordinator.recover();
    expect(result.missing, ['editor']);
    expect(result.restored, isEmpty);
  });
}
