class DraftSnapshot {
  DraftSnapshot({
    required this.formId,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required Map<String, Object?> fields,
    this.expiresAt,
  }) : fields = Map<String, Object?>.unmodifiable(fields) {
    if (formId.trim().isEmpty) {
      throw ArgumentError.value(formId, 'formId', 'Must not be empty.');
    }
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion', 'Must be at least 1.');
    }
  }

  final String formId;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? expiresAt;
  final Map<String, Object?> fields;

  bool isExpiredAt(DateTime time) =>
      expiresAt != null && !expiresAt!.isAfter(time);

  DraftSnapshot copyWith({
    int? schemaVersion,
    DateTime? updatedAt,
    DateTime? expiresAt,
    Map<String, Object?>? fields,
  }) {
    return DraftSnapshot(
      formId: formId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      fields: fields ?? this.fields,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'formId': formId,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'fields': fields,
      };

  factory DraftSnapshot.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Draft snapshot must be a JSON object.');
    }
    final formId = value['formId'];
    final version = value['schemaVersion'];
    final createdAt = value['createdAt'];
    final updatedAt = value['updatedAt'];
    final expiresAt = value['expiresAt'];
    final rawFields = value['fields'];

    if (formId is! String ||
        version is! int ||
        createdAt is! String ||
        updatedAt is! String ||
        (expiresAt != null && expiresAt is! String) ||
        rawFields is! Map) {
      throw const FormatException('Draft snapshot has an invalid structure.');
    }

    final fields = <String, Object?>{};
    for (final entry in rawFields.entries) {
      if (entry.key is! String) {
        throw const FormatException('Draft field identifiers must be strings.');
      }
      fields[entry.key as String] = entry.value;
    }

    return DraftSnapshot(
      formId: formId,
      schemaVersion: version,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
      expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt as String),
      fields: fields,
    );
  }
}
