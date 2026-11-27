/// Storage port. Concrete engines are supplied by independent adapter packages.
/// String values keep serialization and schema ownership with each feature.
abstract interface class ContinuumStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll({String? namespace});
}
