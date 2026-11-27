import 'package:continuum_recovery/continuum_recovery.dart';

import 'draft_field.dart';
import 'draft_privacy_policy.dart';
import 'draft_repository.dart';
import 'draft_migration.dart';
import 'draft_snapshot.dart';
import 'draft_autosave_port.dart';

/// UI-framework-neutral state holder for one form's draft.
class DraftSession {
  DraftSession({
    required this.repository,
    required this.formId,
    required this.schema,
    required Map<String, DraftFieldDefinition> fields,
    DraftPrivacyPolicy? privacyPolicy,
    this.ttl,
    this.clearOnSuccessfulSubmission = true,
  })  : fields = Map<String, DraftFieldDefinition>.unmodifiable(fields),
        privacyPolicy = privacyPolicy ?? DraftPrivacyPolicy() {
    if (formId.trim().isEmpty) {
      throw ArgumentError.value(formId, 'formId', 'Must not be empty.');
    }
    if (ttl != null && (ttl!.isNegative || ttl == Duration.zero)) {
      throw ArgumentError.value(ttl, 'ttl', 'Must be greater than zero.');
    }
    for (final entry in this.fields.entries) {
      if (entry.key != entry.value.id) {
        throw ArgumentError(
          'Field map key "${entry.key}" does not match definition id "${entry.value.id}".',
        );
      }
    }
  }

  final DraftRepository repository;
  final String formId;
  final DraftSchema schema;
  final Map<String, DraftFieldDefinition> fields;
  final DraftPrivacyPolicy privacyPolicy;
  final Duration? ttl;
  final bool clearOnSuccessfulSubmission;

  final Map<String, Object?> _values = <String, Object?>{};
  DraftAutosavePort? _controller;
  int _revision = 0;
  bool _dirty = false;
  bool _submissionFinalizing = false;
  bool _submissionFinalized = false;

  Map<String, Object?> get values =>
      Map<String, Object?>.unmodifiable(_values);
  bool get isDirty => _dirty;
  int get revision => _revision;

  /// Loads and migrates a saved draft. Restore is rejected if local edits exist.
  Future<DraftSnapshot?> restore() async {
    if (_dirty) {
      throw StateError('Cannot restore a draft while the session has unsaved edits.');
    }
    final snapshot = await repository.load(formId: formId, schema: schema);
    _values.clear();
    if (snapshot == null) {
      _revision++;
      _dirty = false;
      return null;
    }
    for (final entry in snapshot.fields.entries) {
      final definition = fields[entry.key];
      if (definition != null && privacyPolicy.allows(definition)) {
        _values[entry.key] = entry.value;
      }
    }
    _revision++;
    _dirty = false;
    // Do not return values that the current privacy policy would exclude.
    return snapshot.copyWith(fields: _values);
  }

  /// Updates one field and requests a debounced autosave.
  Future<CheckpointResult> updateField(String fieldId, Object? value) {
    _ensureEditable();
    final controller = _requireController();
    if (!fields.containsKey(fieldId)) {
      throw ArgumentError.value(fieldId, 'fieldId', 'Field is not registered.');
    }
    if (controller.isDisposed) throw StateError('Draft autosave controller has been disposed.');
    _values[fieldId] = value;
    _revision++;
    _dirty = true;
    return controller.requestCheckpoint();
  }

  /// Applies a group of field changes and schedules one coalesced checkpoint.
  Future<CheckpointResult> updateFields(Map<String, Object?> changes) {
    _ensureEditable();
    final controller = _requireController();
    if (controller.isDisposed) throw StateError('Draft autosave controller has been disposed.');
    for (final fieldId in changes.keys) {
      if (!fields.containsKey(fieldId)) {
        throw ArgumentError.value(fieldId, 'changes', 'Unknown field "$fieldId".');
      }
    }
    if (changes.isNotEmpty) {
      _values.addAll(changes);
      _revision++;
      _dirty = true;
    }
    return controller.requestCheckpoint();
  }

  /// Call only after the server has confirmed a successful submission.
  Future<void> afterSuccessfulSubmission({
    bool? clearDraft,
    bool clearValues = true,
  }) async {
    final shouldClearDraft = clearDraft ?? clearOnSuccessfulSubmission;
    if (shouldClearDraft) {
      if (_submissionFinalizing || _submissionFinalized) {
        throw StateError('Draft submission has already been finalized.');
      }
      _submissionFinalizing = true;
      try {
        final controller = _controller;
        if (controller != null && !controller.isDisposed) {
          await controller.checkpointNow();
        }
        await repository.afterSuccessfulSubmission(
          formId: formId,
          clearDraft: true,
        );
        _dirty = false;
        _submissionFinalized = true;
      } catch (_) {
        _submissionFinalizing = false;
        rethrow;
      } finally {
        _submissionFinalizing = false;
      }
    }
    if (clearValues) {
      _values.clear();
      _revision++;
      _dirty = false;
    }
  }

  /// Attaches this session to one autosave controller.
  ///
  /// Public for package composition; application code should normally call
  /// DraftAutosaveController.register.
  void attachController(DraftAutosavePort controller) {
    if (_controller != null && !identical(_controller, controller)) {
      throw StateError('Draft session is already attached to another controller.');
    }
    _controller = controller;
  }

  void detachController(DraftAutosavePort controller) {
    if (identical(_controller, controller)) _controller = null;
  }

  /// Persists the current revision if dirty. Used by the autosave controller.
  Future<DraftSaveResult?> persistIfDirty() async {
    if (!_dirty) return null;
    final savingRevision = _revision;
    final result = await repository.save(
      formId: formId,
      schema: schema,
      fields: fields,
      values: Map<String, Object?>.of(_values),
      policy: privacyPolicy,
      ttl: ttl,
    );
    // An edit may have arrived during the asynchronous write. In that case,
    // keep the session dirty so the queued checkpoint persists the newer data.
    if (_revision == savingRevision) _dirty = false;
    return result;
  }

  DraftAutosavePort _requireController() {
    final controller = _controller;
    if (controller == null) {
      throw StateError('Register the draft session before updating fields.');
    }
    return controller;
  }
}
