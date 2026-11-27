import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:continuum_recovery/continuum_recovery.dart';
import 'package:test/test.dart';

class _Participant implements RecoveryParticipant {
  _Participant(this.recoveryId, {this.snapshot = 'draft-v1', this.restoreError});
  @override
  final String recoveryId;
  String? snapshot;
  Object? restoreError;
  String? restored;
  @override
  Future<String?> createSnapshot() async => snapshot;
  @override
  Future<void> restoreSnapshot(String value) async {
    if (restoreError != null) throw restoreError!;
    restored = value;
  }
  @override
  Future<void> clearRecoveredState() async {}
}

class _FailingStore extends InMemoryContinuumStore {
  bool failWrites = false;
  @override
  Future<void> write(String key, String value) {
    if (failWrites) throw StateError('storage unavailable');
    return super.write(key, value);
  }
}

void main() {
  test('checkpoints and restores snapshots', () async {
    final store = InMemoryContinuumStore();
    final participant = _Participant('editor');
    final coordinator = RecoveryCoordinator(store: store)..register(participant);
    expect((await coordinator.checkpoint()).saved, ['editor']);
    final result = await coordinator.recover();
    expect(participant.restored, 'draft-v1');
    expect(result.restored, ['editor']);
    expect(result.failed, isEmpty);
  });

  test('null snapshots delete stale data', () async {
    final store = InMemoryContinuumStore();
    final participant = _Participant('editor');
    final coordinator = RecoveryCoordinator(store: store)..register(participant);
    await coordinator.checkpoint();
    participant.snapshot = null;
    expect((await coordinator.checkpoint()).cleared, ['editor']);
    expect((await coordinator.recover()).missing, ['editor']);
  });

  test('isolates storage failures and continues processing', () async {
    final store = _FailingStore()..failWrites = true;
    final coordinator = RecoveryCoordinator(store: store)
      ..register(_Participant('one'))
      ..register(_Participant('two'));
    final result = await coordinator.checkpoint();
    expect(result.failed.keys, containsAll(['one', 'two']));
    expect(result.isSuccessful, isFalse);
  });

  test('isolates restore failures and exposes stage and stack trace', () async {
    final store = InMemoryContinuumStore();
    final broken = _Participant('broken', restoreError: StateError('invalid snapshot'));
    final healthy = _Participant('healthy');
    final coordinator = RecoveryCoordinator(store: store)..register(broken)..register(healthy);
    await coordinator.checkpoint();
    final result = await coordinator.recover();
    expect(result.restored, ['healthy']);
    expect(result.failed['broken']?.stage, RecoveryStage.restore);
    expect(result.failed['broken']?.stackTrace, isNotNull);
  });

  test('serializes concurrent operations', () async {
    final store = InMemoryContinuumStore();
    final coordinator = RecoveryCoordinator(store: store)..register(_Participant('editor'));
    await Future.wait([coordinator.checkpoint(), coordinator.recover(), coordinator.clear('editor')]);
    expect(await store.read('continuum.recovery.editor'), isNull);
  });

  test('rejects duplicate and invalid participant ids', () {
    final coordinator = RecoveryCoordinator(store: InMemoryContinuumStore());
    coordinator.register(_Participant('editor'));
    expect(() => coordinator.register(_Participant('editor')), throwsStateError);
    expect(() => coordinator.register(_Participant('  ')), throwsArgumentError);
  });
}
