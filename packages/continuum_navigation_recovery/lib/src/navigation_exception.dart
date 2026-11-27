enum NavigationRecoveryErrorCode {
  corruptedSnapshot,
  unsupportedVersion,
  missingMigration,
  migrationFailed,
  unknownRoute,
  routeNotRestorable,
  invalidParameters,
  stateCaptureFailed,
  stateRestoreFailed,
}

/// Typed error raised when a navigation snapshot cannot be safely recovered.
class NavigationRecoveryException implements Exception {
  const NavigationRecoveryException({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  final NavigationRecoveryErrorCode code;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'NavigationRecoveryException.${code.name}: $message'
      '${cause == null ? '' : ' — $cause'}';
}
