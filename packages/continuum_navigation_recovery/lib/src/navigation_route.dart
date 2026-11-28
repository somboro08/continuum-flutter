import 'navigation_entry.dart';

typedef NavigationParameterValidator = bool Function(
  Map<String, Object?> parameters,
);

/// Allow-list and validation rules for one application-owned route.
class NavigationRouteDefinition {
  NavigationRouteDefinition({
    required this.routeId,
    Set<String> persistedParameterKeys = const <String>{},
    this.canRestore = true,
    this.validateParameters,
  }) : persistedParameterKeys =
            Set<String>.unmodifiable(persistedParameterKeys) {
    if (routeId.trim().isEmpty) {
      throw ArgumentError.value(routeId, 'routeId', 'Must not be empty.');
    }
    if (this.persistedParameterKeys.any((key) => key.trim().isEmpty)) {
      throw ArgumentError.value(
        persistedParameterKeys,
        'persistedParameterKeys',
        'Parameter keys must not be empty.',
      );
    }
  }

  final String routeId;

  /// Only these keys are copied into persisted snapshots. Defaults to none.
  final Set<String> persistedParameterKeys;

  /// Set false for routes such as login, payment confirmation, or transient UI.
  final bool canRestore;

  /// Optional application-specific validation run both before save and restore.
  final NavigationParameterValidator? validateParameters;

  Map<String, Object?> filterParameters(Map<String, Object?> parameters) {
    return <String, Object?>{
      for (final key in persistedParameterKeys)
        if (parameters.containsKey(key)) key: parameters[key],
    };
  }

  bool accepts(NavigationEntry entry) {
    if (entry.routeId != routeId || !canRestore) return false;
    if (entry.parameters.keys.any(
      (key) => !persistedParameterKeys.contains(key),
    )) {
      return false;
    }
    return validateParameters?.call(entry.parameters) ?? true;
  }
}

/// Immutable allow-list of routes that may participate in recovery.
class NavigationRouteRegistry {
  NavigationRouteRegistry(Iterable<NavigationRouteDefinition> definitions)
      : _routes = _index(definitions);

  final Map<String, NavigationRouteDefinition> _routes;

  NavigationRouteDefinition? operator [](String routeId) => _routes[routeId];

  bool contains(String routeId) => _routes.containsKey(routeId);

  static Map<String, NavigationRouteDefinition> _index(
    Iterable<NavigationRouteDefinition> definitions,
  ) {
    final result = <String, NavigationRouteDefinition>{};
    for (final definition in definitions) {
      if (result.containsKey(definition.routeId)) {
        throw ArgumentError('Duplicate navigation route "${definition.routeId}".');
      }
      result[definition.routeId] = definition;
    }
    return Map<String, NavigationRouteDefinition>.unmodifiable(result);
  }
}
