# continuum_storage_file

A dependency-free file-system adapter for the Continuum persistence contract.

## Usage

```dart
import 'dart:io';
import 'package:continuum_storage_file/continuum_storage_file.dart';

final store = FileContinuumStore(
  directory: Directory('/path/selected/by/the/application'),
);
await store.write('forms.registration', '{"name":"Ada"}');
final draft = await store.read('forms.registration');
```

The application chooses the directory and owns its lifecycle. Keys are encoded
before they are used as file names. Operations are serialized per store instance.
Writes use a temporary file followed by a same-directory rename.

## Security and guarantees

- This adapter does not encrypt values.
- Do not store passwords, OTPs, payment credentials, or other secrets here.
- Atomic replacement depends on the underlying file system and platform.
- This is not a multi-process lock or a transactional database.
- For stronger durability, encryption, migrations, or concurrent multi-isolate
  access, provide a dedicated adapter implementing the persistence contract.
