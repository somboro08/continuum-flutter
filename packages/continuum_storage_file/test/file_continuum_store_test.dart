import 'dart:io';
import 'package:continuum_persistence/continuum_persistence.dart';
import 'package:continuum_storage_file/continuum_storage_file.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late FileContinuumStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('continuum-store-test-');
    store = FileContinuumStore(directory: directory);
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('persists values across store instances', () async {
    await store.write('forms.registration', '{"name":"Ada"}');
    final reopened = FileContinuumStore(directory: directory);
    expect(await reopened.read('forms.registration'), '{"name":"Ada"}');
  });

  test('isolates namespace deletion at a key boundary', () async {
    await store.write('forms.one', '1');
    await store.write('forms.two', '2');
    await store.write('formats.one', '3');
    await store.deleteAll(namespace: 'forms');
    expect(await store.read('forms.one'), isNull);
    expect(await store.read('forms.two'), isNull);
    expect(await store.read('formats.one'), '3');
  });

  test('encodes traversal-like keys instead of using them as paths', () async {
    await store.write('../../outside', 'safe');
    expect(await store.read('../../outside'), 'safe');
    final outside = File('${directory.parent.path}${Platform.pathSeparator}outside.entry');
    expect(await outside.exists(), isFalse);
  });

  test('serializes concurrent writes to the same key', () async {
    await Future.wait([
      store.write('counter', 'first'),
      store.write('counter', 'second'),
      store.write('counter', 'third'),
    ]);
    expect(await store.read('counter'), 'third');
  });

  test('rejects invalid keys with argument errors', () async {
    await expectLater(store.write('  ', 'value'), throwsArgumentError);
  });

  test('missing values return null', () async {
    expect(await store.read('not-found'), isNull);
  });

  test('wraps file-system failures with operation context', () async {
    final blocker = File('${directory.path}${Platform.pathSeparator}not-a-directory');
    await blocker.writeAsString('occupied');
    final brokenStore = FileContinuumStore(directory: Directory(blocker.path));
    await expectLater(
      brokenStore.write('draft', 'value'),
      throwsA(isA<ContinuumStorageException>()
          .having((error) => error.operation, 'operation', ContinuumStorageOperation.write)
          .having((error) => error.key, 'key', 'draft')
          .having((error) => error.stackTrace, 'stackTrace', isNotNull)),
    );
  });
}
