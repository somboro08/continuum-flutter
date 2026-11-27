enum ContinuumStorageOperation { read, write, delete, deleteAll }

class ContinuumStorageException implements Exception {
  const ContinuumStorageException({required this.operation, required this.message, this.key, this.cause, this.stackTrace});
  final ContinuumStorageOperation operation;
  final String message;
  final String? key;
  final Object? cause;
  final StackTrace? stackTrace;
  @override
  String toString() {
    final target = key == null ? '' : ' (key: $key)';
    final original = cause == null ? '' : ': $cause';
    return 'ContinuumStorageException.${operation.name}$target: $message$original';
  }
}

void validateStorageKey(String key, {String parameterName = 'key'}) {
  if (key.trim().isEmpty) throw ArgumentError.value(key, parameterName, 'Must not be empty.');
  if (key.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
    throw ArgumentError.value(key, parameterName, 'Control characters are not allowed.');
  }
}
