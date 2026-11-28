import 'continuum_store.dart';
import 'continuum_store_exception.dart';

/// Adds an isolated namespace to a store without coupling features to its engine.
class NamespacedContinuumStore implements ContinuumStore {
  NamespacedContinuumStore({required ContinuumStore store, required this.namespace}) : _store = store {
    validateStorageKey(namespace, parameterName: 'namespace');
  }
  final ContinuumStore _store;
  final String namespace;
  String _key(String key) {
    validateStorageKey(key);
    return '$namespace.$key';
  }
  @override
  Future<String?> read(String key) => _store.read(_key(key));
  @override
  Future<void> write(String key, String value) => _store.write(_key(key), value);
  @override
  Future<void> delete(String key) => _store.delete(_key(key));
  @override
  Future<void> deleteAll({String? namespace}) {
    if (namespace == null) return _store.deleteAll(namespace: this.namespace);
    validateStorageKey(namespace, parameterName: 'namespace');
    return _store.deleteAll(namespace: '${this.namespace}.$namespace');
  }
}
