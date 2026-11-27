import 'navigation_entry.dart';

/// One deterministic navigation snapshot migration.
class NavigationMigration {
  NavigationMigration({
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
        'Migrations must advance exactly one version.',
      );
    }
  }

  final int fromVersion;
  final int toVersion;
  final List<NavigationEntry> Function(List<NavigationEntry> entries) migrate;
}

/// Current navigation snapshot version and accepted migration chain.
class NavigationRecoverySchema {
  NavigationRecoverySchema({
    required this.version,
    List<NavigationMigration> migrations = const <NavigationMigration>[],
  }) : migrations = List<NavigationMigration>.unmodifiable(migrations) {
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
  final List<NavigationMigration> migrations;

  NavigationMigration? migrationFrom(int version) {
    for (final migration in migrations) {
      if (migration.fromVersion == version) return migration;
    }
    return null;
  }
}
