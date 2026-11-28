import 'package:continuum_persistence/continuum_persistence.dart';

enum DraftFieldSensitivity {
  ordinary,
  personal,
  secret,
  oneTimeCode,
  payment,
}

/// Describes whether a field may be considered for draft persistence.
class DraftFieldDefinition {
  DraftFieldDefinition({
    required this.id,
    this.sensitivity = DraftFieldSensitivity.ordinary,
    this.persist = true,
  }) {
    validateStorageKey(id, parameterName: 'field id');
  }

  final String id;
  final DraftFieldSensitivity sensitivity;
  final bool persist;
}
