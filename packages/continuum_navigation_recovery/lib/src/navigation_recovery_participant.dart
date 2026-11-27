import 'dart:convert';

import 'package:continuum_recovery/continuum_recovery.dart';

import 'navigation_entry.dart';
import 'navigation_exception.dart';
import 'navigation_migration.dart';
import 'navigation_route.dart';
import 'navigation_snapshot.dart';
import 'navigation_state_port.dart';

/// Captures and safely restores an application navigation stack.
///
/// This participant stores only route IDs and explicitly allow-listed
/// parameters. It never imports or controls a concrete router.
class NavigationRecoveryParticipant implements RecoveryParticipant {
  NavigationRecoveryParticipant({
    required this.recoveryId,
    required NavigationStatePort state,
    required NavigationRouteRegistry routes,
    required NavigationRecoverySchema schema,
    DateTime Function()? clock,
  })  : _state = state,
        _routes = routes,
        _schema = schema,
        _clock = clock ?? DateTime.now {
    if (recoveryId.trim().isEmpty) {
      throw ArgumentError.value(
        recoveryId,
        'recoveryId',
        'Must not be empty.',
      );
    }
  }

  @override
  final String recoveryId;

  final NavigationStatePort _state;
  final NavigationRouteRegistry _routes;
  final NavigationRecoverySchema _schema;
  final DateTime Function() _clock;

  @override
  Future<String?> createSnapshot() async {
    late final List<NavigationEntry> current;
    try {
      current = await _state.captureStack();
    } catch (error, stackTrace) {
      throw NavigationRecoveryException(
        code: NavigationRecoveryErrorCode.stateCaptureFailed,
        message: 'Unable to capture the current navigation stack.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (current.isEmpty) return null;

    final safeEntries = <NavigationEntry>[];
    for (final entry in current) {
      final definition = _routes[entry.routeId];
      // A transient/non-restorable route invalidates the entire stack. Saving
      // a partial stack could reopen a screen in an unrelated user context.
      if (definition == null || !definition.canRestore) return null;

      final safeEntry = NavigationEntry(
        routeId: entry.routeId,
        parameters: definition.filterParameters(entry.parameters),
      );
      if (!definition.accepts(safeEntry)) {
        throw NavigationRecoveryException(
          code: NavigationRecoveryErrorCode.invalidParameters,
          message: 'Parameters for route "${entry.routeId}" failed validation.',
        );
      }
      safeEntries.add(safeEntry);
    }

    try {
      return jsonEncode(
        NavigationSnapshot(
          version: _schema.version,
          capturedAt: _clock(),
          entries: safeEntries,
        ).toJson(),
      );
    } catch (error, stackTrace) {
      throw NavigationRecoveryException(
        code: NavigationRecoveryErrorCode.invalidParameters,
        message: 'Navigation state could not be serialized.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> restoreSnapshot(String snapshot) async {
    late NavigationSnapshot decoded;
    try {
      decoded = NavigationSnapshot.fromJson(jsonDecode(snapshot));
    } catch (error, stackTrace) {
      throw NavigationRecoveryException(
        code: NavigationRecoveryErrorCode.corruptedSnapshot,
        message: 'Stored navigation snapshot is malformed.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (decoded.version > _schema.version) {
      throw NavigationRecoveryException(
        code: NavigationRecoveryErrorCode.unsupportedVersion,
        message: 'Snapshot version ${decoded.version} is newer than supported version ${_schema.version}.',
      );
    }

    var entries = decoded.entries;
    var version = decoded.version;
    while (version < _schema.version) {
      final migration = _schema.migrationFrom(version);
      if (migration == null) {
        throw NavigationRecoveryException(
          code: NavigationRecoveryErrorCode.missingMigration,
          message: 'No navigation migration exists from version $version.',
        );
      }
      try {
        entries = List<NavigationEntry>.unmodifiable(
          migration.migrate(List<NavigationEntry>.unmodifiable(entries)),
        );
        version = migration.toVersion;
      } catch (error, stackTrace) {
        throw NavigationRecoveryException(
          code: NavigationRecoveryErrorCode.migrationFailed,
          message: 'Navigation migration from version ${migration.fromVersion} failed.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }

    // Validate the complete stack before asking the router to change anything.
    for (final entry in entries) {
      final definition = _routes[entry.routeId];
      if (definition == null) {
        throw NavigationRecoveryException(
          code: NavigationRecoveryErrorCode.unknownRoute,
          message: 'Route "${entry.routeId}" is not registered for recovery.',
        );
      }
      if (!definition.canRestore) {
        throw NavigationRecoveryException(
          code: NavigationRecoveryErrorCode.routeNotRestorable,
          message: 'Route "${entry.routeId}" is not allowed to be restored.',
        );
      }
      if (!definition.accepts(entry)) {
        throw NavigationRecoveryException(
          code: NavigationRecoveryErrorCode.invalidParameters,
          message: 'Parameters for route "${entry.routeId}" are invalid or not allow-listed.',
        );
      }
    }

    try {
      await _state.replaceStack(List<NavigationEntry>.unmodifiable(entries));
    } catch (error, stackTrace) {
      throw NavigationRecoveryException(
        code: NavigationRecoveryErrorCode.stateRestoreFailed,
        message: 'The navigation adapter could not replace the current stack.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> clearRecoveredState() async {
    try {
      await _state.clearStack();
    } catch (error, stackTrace) {
      throw NavigationRecoveryException(
        code: NavigationRecoveryErrorCode.stateRestoreFailed,
        message: 'The navigation adapter could not clear the recovered stack.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
