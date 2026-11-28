import 'dart:convert';

/// A router-neutral route occurrence in the navigation stack.
///
/// Parameters are defensively copied and deeply immutable. Keep only small,
/// non-sensitive identifiers here; do not store tokens, credentials, or
/// complete domain objects in navigation state.
class NavigationEntry {
  NavigationEntry({
    required this.routeId,
    Map<String, Object?> parameters = const <String, Object?>{},
  }) : parameters = _freezeParameters(parameters) {
    if (routeId.trim().isEmpty) {
      throw ArgumentError.value(routeId, 'routeId', 'Must not be empty.');
    }
  }

  final String routeId;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => <String, Object?>{
        'routeId': routeId,
        'parameters': parameters,
      };

  factory NavigationEntry.fromJson(Object? value) {
    if (value is! Map ||
        value['routeId'] is! String ||
        value['parameters'] is! Map) {
      throw const FormatException('Navigation entry has an invalid structure.');
    }
    final rawParameters = value['parameters'] as Map;
    final parameters = <String, Object?>{};
    for (final entry in rawParameters.entries) {
      if (entry.key is! String) {
        throw const FormatException('Navigation parameter keys must be strings.');
      }
      parameters[entry.key as String] = entry.value;
    }
    return NavigationEntry(
      routeId: value['routeId'] as String,
      parameters: parameters,
    );
  }
}

Map<String, Object?> _freezeParameters(Map<String, Object?> parameters) {
  // JSON round-tripping both validates supported value types and detaches
  // nested collections from caller-owned mutable objects.
  final decoded = jsonDecode(jsonEncode(parameters));
  if (decoded is! Map) {
    throw const FormatException('Navigation parameters must be a JSON object.');
  }
  return Map<String, Object?>.unmodifiable(
    decoded.map((key, value) => MapEntry(key as String, _deepFreeze(value))),
  );
}

Object? _deepFreeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _deepFreeze(item))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_deepFreeze));
  }
  return value;
}
