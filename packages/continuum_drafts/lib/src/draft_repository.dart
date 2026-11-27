import 'dart:convert';

import 'package:continuum_persistence/continuum_persistence.dart';

import 'draft_exception.dart';
import 'draft_field.dart';
import 'draft_migration.dart';
import 'draft_privacy_policy.dart';
import 'draft_snapshot.dart';

class DraftSaveResult {
  const DraftSaveResult({
    required this.formId,
    required this.persistedFieldCount,
    required this.cleared,
    required this.updatedAt,
  });

  final String formId;
  final int persistedFieldCount;
  final bool cleared;
  final DateTime updatedAt;
}

/// Persists versioned form drafts through the platform-neutral storage port.
class DraftRepository {
  DraftRepository({
    required ContinuumStore store,
    this.namespace = 'continuum.drafts',
    DateTime Function()? clock,
  })  : _store = store,
        _clock = clock ?? DateTime.now {
    validateStorageKey(namespace, parameterName: 'namespace');
  }

  final ContinuumStore _store;
  final DateTime Function() _clock;
  final String namespace;

  Future<DraftSaveResult> save({
    required String formId,
    required DraftSchema schema,
    required Map<String, DraftFieldDefinition> fields,
    required Map<String, Object?> values,
    DraftPrivacyPolicy policy = const DraftPrivacyPolicy(),
    Duration? ttl,
  }) async {
    _validateFormId(formId);
    if (ttl != null && (ttl.isNegative || ttl == Duration.zero)) {
      throw ArgumentError.value(ttl, 'ttl', 'Must be greater than zero.');
    }

    final persistable = <String, Object?>{};
    for (final entry in values.entries) {
      final definition = fields[entry.key];
      if (definition == null) continue;
      if (definition.id != entry.key) {
        throw ArgumentError(
          'Field map key "${entry.key}" does not match definition id "${definition.id}".',
        );
      }
      if (policy.allows(definition)) {
        persistable[entry.key] = entry.value;
      }
    }

    final now = _clock();
    if (persistable.isEmpty) {
      await delete(formId);
      return DraftSaveResult(
        formId: formId,
        persistedFieldCount: 0,
        cleared: true,
        updatedAt: now,
      );
    }

    final existing = await _readSnapshot(formId);
    final snapshot = DraftSnapshot(
      formId: formId,
      schemaVersion: schema.version,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      expiresAt: ttl == null ? existing?.expiresAt : now.add(ttl),
      fields: persistable,
    );
    await _writeSnapshot(snapshot);
    return DraftSaveResult(
      formId: formId,
      persistedFieldCount: persistable.length,
      cleared: false,
      updatedAt: now,
    );
  }

  Future<DraftSnapshot?> load({
    required String formId,
    required DraftSchema schema,
  }) async {
    _validateFormId(formId);
    var snapshot = await _readSnapshot(formId);
    if (snapshot == null) return null;

    if (snapshot.isExpiredAt(_clock())) {
      await delete(formId);
      return null;
    }
    if (snapshot.schemaVersion > schema.version) {
      throw DraftException(
        code: DraftErrorCode.unsupportedVersion,
        formId: formId,
        message: 'Stored schema version ${snapshot.schemaVersion} is newer than supported version ${schema.version}.',
      );
    }

    var migrated = false;
    while (snapshot.schemaVersion < schema.version) {
      final migration = schema.migrationFrom(snapshot.schemaVersion);
      if (migration == null) {
        throw DraftException(
          code: DraftErrorCode.missingMigration,
          formId: formId,
          message: 'No migration exists from schema version ${snapshot.schemaVersion}.',
        );
      }
      try {
        final nextFields = migration.migrate(
          Map<String, Object?>.unmodifiable(snapshot.fields),
        );
        snapshot = snapshot.copyWith(
          schemaVersion: migration.toVersion,
          updatedAt: _clock(),
          fields: nextFields,
        );
        migrated = true;
      } catch (error, stackTrace) {
        throw DraftException(
          code: DraftErrorCode.migrationFailed,
          formId: formId,
          message: 'Migration from version ${migration.fromVersion} failed.',
          cause: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (migrated) await _writeSnapshot(snapshot);
    return snapshot;
  }

  Future<void> delete(String formId) async {
    _validateFormId(formId);
    try {
      await _store.delete(_storageKey(formId));
    } catch (error, stackTrace) {
      throw DraftException(
        code: DraftErrorCode.storage,
        formId: formId,
        message: 'Unable to delete the stored draft.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Call this only after the remote form submission has succeeded.
  Future<void> afterSuccessfulSubmission({
    required String formId,
    bool clearDraft = true,
  }) async {
    if (clearDraft) await delete(formId);
  }

  Future<DraftSnapshot?> _readSnapshot(String formId) async {
    String? raw;
    try {
      raw = await _store.read(_storageKey(formId));
    } catch (error, stackTrace) {
      throw DraftException(
        code: DraftErrorCode.storage,
        formId: formId,
        message: 'Unable to read the stored draft.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (raw == null) return null;

    try {
      final snapshot = DraftSnapshot.fromJson(jsonDecode(raw));
      if (snapshot.formId != formId) {
        throw DraftException(
          code: DraftErrorCode.formMismatch,
          formId: formId,
          message: 'Stored draft belongs to "${snapshot.formId}".',
        );
      }
      return snapshot;
    } on DraftException {
      rethrow;
    } catch (error, stackTrace) {
      throw DraftException(
        code: DraftErrorCode.corruptedSnapshot,
        formId: formId,
        message: 'Stored draft cannot be decoded or validated.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _writeSnapshot(DraftSnapshot snapshot) async {
    String encoded;
    try {
      encoded = jsonEncode(snapshot.toJson());
    } catch (error, stackTrace) {
      throw DraftException(
        code: DraftErrorCode.serialization,
        formId: snapshot.formId,
        message: 'Draft contains a value that cannot be serialized as JSON.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await _store.write(_storageKey(snapshot.formId), encoded);
    } catch (error, stackTrace) {
      throw DraftException(
        code: DraftErrorCode.storage,
        formId: snapshot.formId,
        message: 'Unable to persist the draft.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _storageKey(String formId) =>
      '$namespace.${Uri.encodeComponent(formId)}';

  void _validateFormId(String formId) {
    validateStorageKey(formId, parameterName: 'formId');
  }
}
