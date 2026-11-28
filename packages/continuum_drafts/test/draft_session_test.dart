import 'dart:async';

import 'package:continuum_drafts/continuum_drafts.dart';
import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:test/test.dart';

void main() {
  group('DraftSession and autosave', () {
    late InMemoryContinuumStore store;
    late DraftRepository repository;
    final definitions = <String, DraftFieldDefinition>{
      'name': DraftFieldDefinition(id: 'name'),
      'password': DraftFieldDefinition(
        id: 'password',
        sensitivity: DraftFieldSensitivity.secret,
      ),
    };

    setUp(() {
      store = InMemoryContinuumStore();
      repository = DraftRepository(store: store);
    });

    test('autosaves updates and restores them into a new session', () async {
      final session = DraftSession(
        repository: repository,
        formId: 'registration',
        schema: DraftSchema(version: 1),
        fields: definitions,
      );
      final autosave = DraftAutosaveController(
        debounce: Duration.zero,
        minimumInterval: Duration.zero,
      )..register(session);

      final result = await session.updateFields({
        'name': 'Grace',
        'password': 'never-persist',
      });

      expect(result.isSuccessful, isTrue);
      expect(session.isDirty, isFalse);

      final restored = DraftSession(
        repository: repository,
        formId: 'registration',
        schema: DraftSchema(version: 1),
        fields: definitions,
      );
      await restored.restore();

      expect(restored.values, {'name': 'Grace'});
      expect(restored.values.containsKey('password'), isFalse);
      await autosave.dispose();
    });

    test('preserves edits made while a write is in flight', () async {
      final delayedStore = _DelayedFirstWriteStore();
      final delayedRepository = DraftRepository(store: delayedStore);
      final session = DraftSession(
        repository: delayedRepository,
        formId: 'race',
        schema: DraftSchema(version: 1),
        fields: definitions,
      );
      final autosave = DraftAutosaveController(
        debounce: Duration.zero,
        minimumInterval: Duration.zero,
      )..register(session);

      final firstRequest = session.updateField('name', 'first');
      await delayedStore.writeStarted.future;
      final secondRequest = session.updateField('name', 'second');
      delayedStore.releaseWrite.complete();

      expect((await firstRequest).isSuccessful, isTrue);
      expect((await secondRequest).isSuccessful, isTrue);
      expect(session.isDirty, isFalse);

      final snapshot = await delayedRepository.load(
        formId: 'race',
        schema: DraftSchema(version: 1),
      );
      expect(snapshot!.fields['name'], 'second');
      await autosave.dispose();
    });

    test('reports storage failures and keeps the session dirty', () async {
      final failingStore = _FailingWriteStore();
      final failingRepository = DraftRepository(store: failingStore);
      final session = DraftSession(
        repository: failingRepository,
        formId: 'failure',
        schema: DraftSchema(version: 1),
        fields: definitions,
      );
      final autosave = DraftAutosaveController(
        debounce: Duration.zero,
        minimumInterval: Duration.zero,
      )..register(session);

      final result = await session.updateField('name', 'Grace');

      expect(result.isSuccessful, isFalse);
      expect(result.failed.keys, contains('failure'));
      expect(session.isDirty, isTrue);
      await autosave.dispose(flushPending: false);
    });

    test('clears persisted and in-memory values after successful submission',
        () async {
      final session = DraftSession(
        repository: repository,
        formId: 'submitted',
        schema: DraftSchema(version: 1),
        fields: definitions,
      );
      final autosave = DraftAutosaveController(
        debounce: Duration.zero,
        minimumInterval: Duration.zero,
      )..register(session);

      await session.updateField('name', 'Grace');
      await session.afterSuccessfulSubmission();

      expect(session.values, isEmpty);
      expect(session.isDirty, isFalse);
      expect(
        () => session.updateField('name', 'after-submit'),
        throwsStateError,
      );
      expect(
        await repository.load(
          formId: 'submitted',
          schema: DraftSchema(version: 1),
        ),
        isNull,
      );
      await autosave.dispose();
    });

    test('rejects unknown fields without mutating the session', () async {
      final session = DraftSession(
        repository: repository,
        formId: 'unknown-field',
        schema: DraftSchema(version: 1),
        fields: definitions,
      );
      final autosave = DraftAutosaveController()..register(session);

      expect(
        () => session.updateField('unknown', 'value'),
        throwsArgumentError,
      );
      expect(session.values, isEmpty);
      await autosave.dispose(flushPending: false);
    });
  });
}

class _DelayedFirstWriteStore implements ContinuumStore {
  final InMemoryContinuumStore _delegate = InMemoryContinuumStore();
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> releaseWrite = Completer<void>();
  bool _delayed = false;

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (!_delayed) {
      _delayed = true;
      writeStarted.complete();
      await releaseWrite.future;
    }
    await _delegate.write(key, value);
  }

  @override
  Future<void> delete(String key) => _delegate.delete(key);

  @override
  Future<void> deleteAll({String? namespace}) =>
      _delegate.deleteAll(namespace: namespace);
}

class _FailingWriteStore implements ContinuumStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    throw StateError('Simulated storage failure');
  }

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll({String? namespace}) async {}
}
