import 'package:continuum_drafts/continuum_drafts.dart';
import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:test/test.dart';

void main() {
  group('DraftRepository', () {
    late InMemoryContinuumStore store;
    late DraftRepository repository;
    final fields = <String, DraftFieldDefinition>{
      'name': DraftFieldDefinition(id: 'name'),
      'email': DraftFieldDefinition(
        id: 'email',
        sensitivity: DraftFieldSensitivity.personal,
      ),
      'password': DraftFieldDefinition(
        id: 'password',
        sensitivity: DraftFieldSensitivity.secret,
      ),
      'otp': DraftFieldDefinition(
        id: 'otp',
        sensitivity: DraftFieldSensitivity.oneTimeCode,
      ),
      'card': DraftFieldDefinition(
        id: 'card',
        sensitivity: DraftFieldSensitivity.payment,
      ),
    };

    setUp(() {
      store = InMemoryContinuumStore();
      repository = DraftRepository(store: store);
    });

    test('persists ordinary fields and excludes sensitive fields by default',
        () async {
      await repository.save(
        formId: 'signup',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {
          'name': 'Ada',
          'email': 'ada@example.com',
          'password': 'not-to-store',
          'otp': '123456',
          'card': '4111111111111111',
        },
      );

      final draft = await repository.load(
        formId: 'signup',
        schema: DraftSchema(version: 1),
      );

      expect(draft!.fields, {'name': 'Ada'});
      expect(draft.fields.containsKey('password'), isFalse);
      expect(draft.fields.containsKey('otp'), isFalse);
      expect(draft.fields.containsKey('card'), isFalse);
    });

    test('allows personal fields only when explicitly allow-listed', () async {
      await repository.save(
        formId: 'profile',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'name': 'Ada', 'email': 'ada@example.com'},
        policy: DraftPrivacyPolicy(
          allowedSensitivities: {
            DraftFieldSensitivity.ordinary,
            DraftFieldSensitivity.personal,
          },
        ),
      );

      final draft = await repository.load(
        formId: 'profile',
        schema: DraftSchema(version: 1),
      );
      expect(draft!.fields, {
        'name': 'Ada',
        'email': 'ada@example.com',
      });
    });

    test('expires drafts and removes their stored value', () async {
      var now = DateTime.utc(2026, 1, 1);
      final expiringRepository = DraftRepository(
        store: store,
        clock: () => now,
      );
      await expiringRepository.save(
        formId: 'temporary',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'name': 'Ada'},
        ttl: const Duration(minutes: 5),
      );

      now = now.add(const Duration(minutes: 6));
      expect(
        await expiringRepository.load(
          formId: 'temporary',
          schema: DraftSchema(version: 1),
        ),
        isNull,
      );
      expect(store.length, 0);
    });

    test('migrates sequentially and persists the new schema version',
        () async {
      await repository.save(
        formId: 'profile',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'name': 'Ada Lovelace'},
      );

      final migrated = await repository.load(
        formId: 'profile',
        schema: DraftSchema(
          version: 2,
          migrations: [
            DraftMigration(
              fromVersion: 1,
              toVersion: 2,
              migrate: (values) => {
                ...values,
                'displayName': values['name'],
              },
            ),
          ],
        ),
      );

      expect(migrated!.schemaVersion, 2);
      expect(migrated.fields['displayName'], 'Ada Lovelace');

      final reloaded = await repository.load(
        formId: 'profile',
        schema: DraftSchema(version: 2),
      );
      expect(reloaded!.schemaVersion, 2);
    });

    test('rejects a draft created by a newer schema', () async {
      await repository.save(
        formId: 'future',
        schema: DraftSchema(version: 3),
        fields: fields,
        values: const {'name': 'Ada'},
      );

      await expectLater(
        repository.load(formId: 'future', schema: DraftSchema(version: 2)),
        throwsA(
          isA<DraftException>().having(
            (error) => error.code,
            'code',
            DraftErrorCode.unsupportedVersion,
          ),
        ),
      );
    });

    test('reports a missing migration instead of dropping old data',
        () async {
      await repository.save(
        formId: 'legacy',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'name': 'Ada'},
      );

      await expectLater(
        repository.load(formId: 'legacy', schema: DraftSchema(version: 2)),
        throwsA(
          isA<DraftException>().having(
            (error) => error.code,
            'code',
            DraftErrorCode.missingMigration,
          ),
        ),
      );
    });

    test('reports values that cannot be JSON serialized', () async {
      await expectLater(
        repository.save(
          formId: 'invalid',
          schema: DraftSchema(version: 1),
          fields: fields,
          values: {'name': Object()},
        ),
        throwsA(
          isA<DraftException>().having(
            (error) => error.code,
            'code',
            DraftErrorCode.serialization,
          ),
        ),
      );
    });

    test('clears a draft after a successful submission', () async {
      await repository.save(
        formId: 'checkout',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'name': 'Ada'},
      );

      await repository.afterSuccessfulSubmission(formId: 'checkout');

      expect(
        await repository.load(
          formId: 'checkout',
          schema: DraftSchema(version: 1),
        ),
        isNull,
      );
    });

    test('deletes stale data when no field is eligible for persistence',
        () async {
      await repository.save(
        formId: 'signup',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'name': 'Ada'},
      );

      final result = await repository.save(
        formId: 'signup',
        schema: DraftSchema(version: 1),
        fields: fields,
        values: const {'password': 'secret'},
      );

      expect(result.cleared, isTrue);
      expect(
        await repository.load(
          formId: 'signup',
          schema: DraftSchema(version: 1),
        ),
        isNull,
      );
    });
  });
}
