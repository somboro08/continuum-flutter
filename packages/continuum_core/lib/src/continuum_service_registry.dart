/// Typed registry for optional platform and application adapters.
class ContinuumServiceRegistry {
  final Map<Type, Object> _services = <Type, Object>{};

  void register<T extends Object>(T service) {
    if (_services.containsKey(T)) {
      throw StateError('A service of type $T is already registered.');
    }
    _services[T] = service;
  }

  T get<T extends Object>() {
    final service = _services[T];
    if (service == null) throw StateError('No service registered for type $T.');
    return service as T;
  }

  T? tryGet<T extends Object>() => _services[T] as T?;
  bool contains<T extends Object>() => _services.containsKey(T);
  void unregister<T extends Object>() => _services.remove(T);
}
