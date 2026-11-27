/// A deterministic, one-version migration for a form's draft payload.
class DraftMigration {
  DraftMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.migrate,
  }) {
    if (fromVersion < 1) {
      throw ArgumentError.value(fromVersion, 'fromVersion', 'Must be at least 1.');
    }
    if (toVersion != fromVersion + 1) {
      throw ArgumentError.value(
        toVersion,
        'toVersion',
        'Migrations must advance exactly one schema version.',
      );
    }
  }

  final int fromVersion;
  final int toVersion;
  final Map<String, Object?> Function(Map<String, Object?> fields) migrate;
}

/// Current form schema and the migrations accepted by that form.
class DraftSchema {
  DraftSchema({required this.version, List<DraftMigration> migrations = const []})
      : migrations = List<DraftMigration>.unmodifiable(migrations) {
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'Must be at least 1.');
    }
    final seen = <int>{};
    for (final migration in this.migrations) {
      if (!seen.add(migration.fromVersion)) {
        throw ArgumentError.value(
          migrations,
          'migrations',
          'Only one migration may start from a given version.',
        );
      }
      if (migration.toVersion > version) {
        throw ArgumentError.value(
          migration,
          'migrations',
          'A migration cannot target a version newer than the current schema.',
        );
      }
    }
  }

  final int version;
  final List<DraftMigration> migrations;

  DraftMigration? migrationFrom(int version) {
    for (final migration in migrations) {
      if (migration.fromVersion == version) return migration;
    }
    return null;
  }
}
