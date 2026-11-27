import 'navigation_entry.dart';

class NavigationSnapshot {
  NavigationSnapshot({
    required this.version,
    required this.capturedAt,
    required List<NavigationEntry> entries,
  }) : entries = List<NavigationEntry>.unmodifiable(entries) {
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'Must be at least 1.');
    }
  }

  final int version;
  final DateTime capturedAt;
  final List<NavigationEntry> entries;

  Map<String, Object?> toJson() => <String, Object?>{
        'version': version,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };

  factory NavigationSnapshot.fromJson(Object? value) {
    if (value is! Map ||
        value['version'] is! int ||
        value['capturedAt'] is! String ||
        value['entries'] is! List) {
      throw const FormatException('Navigation snapshot has an invalid structure.');
    }
    final rawEntries = value['entries'] as List;
    return NavigationSnapshot(
      version: value['version'] as int,
      capturedAt: DateTime.parse(value['capturedAt'] as String),
      entries: rawEntries.map(NavigationEntry.fromJson).toList(growable: false),
    );
  }
}
