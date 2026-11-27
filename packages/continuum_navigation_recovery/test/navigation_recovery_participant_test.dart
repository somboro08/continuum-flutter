import 'dart:convert';

import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';
import 'package:test/test.dart';

void main() {
  group('NavigationRecoveryParticipant', () {
    late _FakeNavigationState state;
    late NavigationRouteRegistry routes;

    setUp(() {
      state = _FakeNavigationState();
      routes = NavigationRouteRegistry([
        NavigationRouteDefinition(
          routeId: 'home',
        ),
        NavigationRouteDefinition(
          routeId: 'profile',
          persistedParameterKeys: {'userId', 'tab'},
          validateParameters: (parameters) =>
              parameters['userId'] is String &&
              (parameters['tab'] == null || parameters['tab'] is String),
        ),
        NavigationRouteDefinition(
          routeId: 'login',
          canRestore: false,
        ),
      ]);
    });

    NavigationRecoveryParticipant participant({
      NavigationRecoverySchema? schema,
    }) =>
        NavigationRecoveryParticipant(
          recoveryId: 'app.navigation',
          state: state,
          routes: routes,
          schema: schema ?? NavigationRecoverySchema(version: 1),
          clock: () => DateTime.utc(2026, 11, 28),
        );

    test('captures route IDs and only explicitly allow-listed parameters',
        () async {
      state.stack = [
        NavigationEntry(routeId: 'home'),
        NavigationEntry(
          routeId: 'profile',
          parameters: {
            'userId': 'user-42',
            'tab': 'activity',
            'accessToken': 'must-not-persist',
          },
        ),
      ];

      final raw = await participant().createSnapshot();
      final decoded = NavigationSnapshot.fromJson(jsonDecode(raw!));

      expect(decoded.entries.map((entry) => entry.routeId),
          ['home', 'profile']);
      expect(decoded.entries.last.parameters, {
        'userId': 'user-42',
        'tab': 'activity',
      });
      expect(raw, isNot(contains('must-not-persist')));
    });

    test('returns null for an empty stack', () async {
      expect(await participant().createSnapshot(), isNull);
    });

    test('clears old checkpoint when stack contains a non-restorable route',
        () async {
      state.stack = [
        NavigationEntry(routeId: 'home'),
        NavigationEntry(routeId: 'login'),
      ];

      expect(await participant().createSnapshot(), isNull);
    });

    test('restores a complete validated stack', () async {
      final snapshot = NavigationSnapshot(
        version: 1,
        capturedAt: DateTime.utc(2026),
        entries: [
          NavigationEntry(routeId: 'home'),
          NavigationEntry(
            routeId: 'profile',
            parameters: {'userId': 'user-7', 'tab': 'settings'},
          ),
        ],
      );

      await participant().restoreSnapshot(jsonEncode(snapshot.toJson()));

      expect(state.replaceCalls, 1);
      expect(state.stack.last.routeId, 'profile');
      expect(state.stack.last.parameters['userId'], 'user-7');
    });

    test('rejects unknown routes without partially replacing the stack',
        () async {
      final snapshot = NavigationSnapshot(
        version: 1,
        capturedAt: DateTime.utc(2026),
        entries: [
          NavigationEntry(routeId: 'home'),
          NavigationEntry(routeId: 'removed-route'),
        ],
      );

      await expectLater(
        participant().restoreSnapshot(jsonEncode(snapshot.toJson())),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.unknownRoute,
          ),
        ),
      );
      expect(state.replaceCalls, 0);
    });

    test('rejects parameters that are not allow-listed', () async {
      final snapshot = NavigationSnapshot(
        version: 1,
        capturedAt: DateTime.utc(2026),
        entries: [
          NavigationEntry(
            routeId: 'profile',
            parameters: {'userId': 'u1', 'password': 'secret'},
          ),
        ],
      );

      await expectLater(
        participant().restoreSnapshot(jsonEncode(snapshot.toJson())),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.invalidParameters,
          ),
        ),
      );
      expect(state.replaceCalls, 0);
    });

    test('rejects route parameters that fail application validation', () async {
      state.stack = [
        NavigationEntry(
          routeId: 'profile',
          parameters: {'userId': 123},
        ),
      ];

      await expectLater(
        participant().createSnapshot(),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.invalidParameters,
          ),
        ),
      );
    });

    test('migrates sequentially before applying the stack', () async {
      final oldSnapshot = NavigationSnapshot(
        version: 1,
        capturedAt: DateTime.utc(2026),
        entries: [
          NavigationEntry(
            routeId: 'profile',
            parameters: {'userId': 'u1'},
          ),
        ],
      );
      final schema = NavigationRecoverySchema(
        version: 2,
        migrations: [
          NavigationMigration(
            fromVersion: 1,
            toVersion: 2,
            migrate: (entries) => [
              for (final entry in entries)
                if (entry.routeId == 'profile')
                  NavigationEntry(
                    routeId: entry.routeId,
                    parameters: {...entry.parameters, 'tab': 'overview'},
                  )
                else
                  entry,
            ],
          ),
        ],
      );

      await participant(schema: schema)
          .restoreSnapshot(jsonEncode(oldSnapshot.toJson()));

      expect(state.stack.single.parameters['tab'], 'overview');
      expect(state.replaceCalls, 1);
    });

    test('rejects future versions and missing migrations', () async {
      final future = NavigationSnapshot(
        version: 3,
        capturedAt: DateTime.utc(2026),
        entries: [NavigationEntry(routeId: 'home')],
      );
      await expectLater(
        participant().restoreSnapshot(jsonEncode(future.toJson())),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.unsupportedVersion,
          ),
        ),
      );

      final old = NavigationSnapshot(
        version: 1,
        capturedAt: DateTime.utc(2026),
        entries: [NavigationEntry(routeId: 'home')],
      );
      await expectLater(
        participant(
          schema: NavigationRecoverySchema(version: 2),
        ).restoreSnapshot(jsonEncode(old.toJson())),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.missingMigration,
          ),
        ),
      );
    });

    test('clears navigation state when explicitly requested', () async {
      state.stack = [NavigationEntry(routeId: 'home')];

      await participant().clearRecoveredState();

      expect(state.stack, isEmpty);
      expect(state.clearCalls, 1);
    });

    test('wraps adapter failures with typed errors', () async {
      state.failCapture = true;
      await expectLater(
        participant().createSnapshot(),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.stateCaptureFailed,
          ),
        ),
      );

      state.failCapture = false;
      state.failReplace = true;
      final snapshot = NavigationSnapshot(
        version: 1,
        capturedAt: DateTime.utc(2026),
        entries: [NavigationEntry(routeId: 'home')],
      );
      await expectLater(
        participant().restoreSnapshot(jsonEncode(snapshot.toJson())),
        throwsA(
          isA<NavigationRecoveryException>().having(
            (error) => error.code,
            'code',
            NavigationRecoveryErrorCode.stateRestoreFailed,
          ),
        ),
      );
    });
  });

  test('NavigationEntry deeply detaches nested parameter values', () {
    final nested = <String, Object?>{'tags': <Object?>['one']};
    final entry = NavigationEntry(
      routeId: 'profile',
      parameters: {'payload': nested},
    );
    (nested['tags'] as List<Object?>).add('two');

    expect(
      (entry.parameters['payload'] as Map<String, Object?>)['tags'],
      ['one'],
    );
  });
}

class _FakeNavigationState implements NavigationStatePort {
  List<NavigationEntry> stack = [];
  int replaceCalls = 0;
  int clearCalls = 0;
  bool failCapture = false;
  bool failReplace = false;

  @override
  Future<List<NavigationEntry>> captureStack() async {
    if (failCapture) throw StateError('capture failed');
    return List<NavigationEntry>.of(stack);
  }

  @override
  Future<void> replaceStack(List<NavigationEntry> entries) async {
    replaceCalls++;
    if (failReplace) throw StateError('replace failed');
    stack = List<NavigationEntry>.of(entries);
  }

  @override
  Future<void> clearStack() async {
    clearCalls++;
    stack = [];
  }
}
