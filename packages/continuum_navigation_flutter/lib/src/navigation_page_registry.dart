import 'package:flutter/widgets.dart';

import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';

/// Creates a declarative Flutter [Page] for a router-neutral navigation entry.
///
/// Factories should return pages with stable, unique keys for each occurrence
/// in the stack. Do not place controllers, BuildContexts, widgets, credentials,
/// or non-serializable objects in [NavigationEntry.parameters].
typedef NavigationPageFactory = Page<dynamic> Function(
  NavigationEntry entry,
);

/// Immutable mapping between Continuum route IDs and application page factories.
///
/// This registry is deliberately separate from [NavigationRouteRegistry]:
/// the latter defines what is safe to persist, while this registry knows how
/// the host application builds Flutter pages.
class NavigationPageRegistry {
  NavigationPageRegistry(Map<String, NavigationPageFactory> factories)
      : _factories = Map<String, NavigationPageFactory>.unmodifiable(
          _validate(factories),
        );

  final Map<String, NavigationPageFactory> _factories;

  NavigationPageFactory? operator [](String routeId) => _factories[routeId];

  bool contains(String routeId) => _factories.containsKey(routeId);

  static Map<String, NavigationPageFactory> _validate(
    Map<String, NavigationPageFactory> factories,
  ) {
    for (final routeId in factories.keys) {
      if (routeId.trim().isEmpty) {
        throw ArgumentError.value(
          routeId,
          'factories',
          'Route IDs must not be empty.',
        );
      }
    }
    return factories;
  }
}
