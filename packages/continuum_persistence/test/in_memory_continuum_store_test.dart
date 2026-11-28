import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryContinuumStore', () {
    test('reads, overwrites and deletes values', () async {
      final store = InMemoryContinuumStore();
      await store.write('draft.1', 'first');
      await store.write('draft.1', 'second');
      expect(await store.read('draft.1'), 'second');
      await store.delete('draft.1');
      expect(await store.read('draft.1'), isNull);
    });
    test('deleteAll respects namespace boundaries', () async {
      final store = InMemoryContinuumStore();
      await store.write('app.forms.one', '1');
      await store.write('app.formats.one', '2');
      await store.deleteAll(namespace: 'app.forms');
      expect(await store.read('app.forms.one'), isNull);
      expect(await store.read('app.formats.one'), '2');
    });
    test('rejects empty and control-character keys', () async {
      final store = InMemoryContinuumStore();
      await expectLater(store.read('  '), throwsArgumentError);
      await expectLater(store.write('bad\nkey', 'value'), throwsArgumentError);
    });
  });
  test('namespaced stores cannot clear sibling namespaces', () async {
    final base = InMemoryContinuumStore();
    final forms = NamespacedContinuumStore(store: base, namespace: 'app.forms');
    final search = NamespacedContinuumStore(store: base, namespace: 'app.search');
    await forms.write('draft', 'form');
    await search.write('history', 'query');
    await forms.deleteAll();
    expect(await forms.read('draft'), isNull);
    expect(await search.read('history'), 'query');
  });
}
