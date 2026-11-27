import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:test/test.dart';

class _MemoryStore implements ContinuumStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> deleteAll({String? namespace}) async {
    if (namespace == null) {
      values.clear();
    } else {
      values.removeWhere((key, _) => key.startsWith('$namespace.'));
    }
  }
}

void main() {
  test('storage contract supports write, read and delete', () async {
    final store = _MemoryStore();
    await store.write('draft.1', 'snapshot');
    expect(await store.read('draft.1'), 'snapshot');
    await store.delete('draft.1');
    expect(await store.read('draft.1'), isNull);
  });
}
