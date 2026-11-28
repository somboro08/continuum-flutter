import 'continuum_store.dart';
import 'continuum_store_exception.dart';

/// Deterministic process-local store for tests and explicitly ephemeral use.
/// Values disappear when the process exits; this implementation is not durable.
class InMemoryContinuumStore implements ContinuumStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    validateStorageKey(key);
    return _values[key];
  }
  @override
  Future<void> write(String key, String value) async {
    validateStorageKey(key);
    _values[key] = value;
  }
  @override
  Future<void> delete(String key) async {
    validateStorageKey(key);
    _values.remove(key);
  }
  @override
  Future<void> deleteAll({String? namespace}) async {
    if (namespace == null) {
      _values.clear();
      return;
    }
    validateStorageKey(namespace, parameterName: 'namespace');
    final prefix = '$namespace.';
    _values.removeWhere((key, _) => key.startsWith(prefix));
  }
  int get length => _values.length;
}
