import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:continuum_persistence/continuum_persistence.dart';

/// Durable, dependency-free storage adapter backed by files.
///
/// Keys are encoded before becoming file names, so user-provided keys cannot
/// escape the configured directory. Writes use a temporary file in the same
/// directory and rename it into place. This is a best-effort atomic replacement
/// on local file systems; it is not a substitute for a transactional database.
///
/// This adapter does not encrypt data. Do not use it for secrets or payment
/// credentials unless an encryption layer is added by the application.
class FileContinuumStore implements ContinuumStore {
  FileContinuumStore({required Directory directory}) : _directory = directory;

  final Directory _directory;
  Future<void> _operationTail = Future<void>.value();
  static int _temporaryFileSequence = 0;

  Future<void> _ensureDirectory() async {
    if (!await _directory.exists()) await _directory.create(recursive: true);
  }

  File _fileFor(String key) {
    validateStorageKey(key);
    final encoded = base64Url.encode(utf8.encode(key));
    return File('${_directory.path}${Platform.pathSeparator}$encoded.entry');
  }

  String? _keyFromFile(File file) {
    final name = file.uri.pathSegments.isEmpty ? '' : file.uri.pathSegments.last;
    if (!name.endsWith('.entry')) return null;
    final encoded = name.substring(0, name.length - '.entry'.length);
    try {
      return utf8.decode(base64Url.decode(encoded));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<String?> read(String key) => _exclusive(() async {
    validateStorageKey(key);
    final file = _fileFor(key);
    try {
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (error, stackTrace) {
      throw ContinuumStorageException(operation: ContinuumStorageOperation.read,
        key: key, message: 'Unable to read the stored value.', cause: error, stackTrace: stackTrace);
    }
  });

  @override
  Future<void> write(String key, String value) => _exclusive(() async {
    validateStorageKey(key);
    final target = _fileFor(key);
    File? temporary;
    try {
      await _ensureDirectory();
      final suffix = '${pid}-${_temporaryFileSequence++}';
      temporary = File('${target.path}.tmp-$suffix');
      await temporary.writeAsString(value, flush: true);
      await temporary.rename(target.path);
    } catch (error, stackTrace) {
      if (temporary != null) {
        try {
          if (await temporary.exists()) await temporary.delete();
        } catch (_) {
          // Preserve the original write failure; temporary cleanup is best effort.
        }
      }
      throw ContinuumStorageException(operation: ContinuumStorageOperation.write,
        key: key, message: 'Unable to persist the value. The previous value is preserved when atomic rename is supported.',
        cause: error, stackTrace: stackTrace);
    }
  });

  @override
  Future<void> delete(String key) => _exclusive(() async {
    validateStorageKey(key);
    try {
      final file = _fileFor(key);
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      throw ContinuumStorageException(operation: ContinuumStorageOperation.delete,
        key: key, message: 'Unable to delete the stored value.', cause: error, stackTrace: stackTrace);
    }
  });

  @override
  Future<void> deleteAll({String? namespace}) => _exclusive(() async {
    if (namespace != null) validateStorageKey(namespace, parameterName: 'namespace');
    try {
      if (!await _directory.exists()) return;
      final failures = <Object>[];
      await for (final entity in _directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.entry')) continue;
        final key = _keyFromFile(entity);
        if (key == null) continue;
        if (namespace != null && !key.startsWith('$namespace.')) continue;
        try {
          await entity.delete();
        } catch (error) {
          failures.add(error);
        }
      }
      if (failures.isNotEmpty) {
        throw ContinuumStorageException(operation: ContinuumStorageOperation.deleteAll,
          message: 'Failed to delete ${failures.length} stored value(s).', cause: failures);
      }
    } on ContinuumStorageException {
      rethrow;
    } catch (error, stackTrace) {
      throw ContinuumStorageException(operation: ContinuumStorageOperation.deleteAll,
        message: 'Unable to enumerate or clear stored values.', cause: error, stackTrace: stackTrace);
    }
  });

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _operationTail;
    final release = Completer<void>();
    _operationTail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }
}
