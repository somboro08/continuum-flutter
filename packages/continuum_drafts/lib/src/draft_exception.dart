enum DraftErrorCode {
  storage,
  serialization,
  corruptedSnapshot,
  formMismatch,
  unsupportedVersion,
  missingMigration,
  migrationFailed,
}

/// Typed failure raised by the draft persistence layer.
class DraftException implements Exception {
  const DraftException({
    required this.code,
    required this.formId,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final DraftErrorCode code;
  final String formId;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'DraftException.${code.name} (form: $formId): $message'
      '${cause == null ? '' : ' — $cause'}';
}
