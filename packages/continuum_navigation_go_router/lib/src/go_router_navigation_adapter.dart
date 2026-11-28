import 'dart:async';

import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';
import 'package:go_router/go_router.dart';

/// Reads the application's complete, router-neutral navigation stack.
///
/// GoRouter supports nested routes, shell routes, imperative pushes and
/// redirects. There is no single portable mapping from all of those concepts
/// to Continuum entries, so the host application supplies this projection.
typedef GoRouterStackReader = FutureOr<List<NavigationEntry>> Function(
  GoRouter router,
);

/// Rebuilds the application's navigation stack from validated Continuum entries.
///
/// Implementations should validate and resolve the complete target before
/// navigating. GoRouter redirects, guards and asynchronous route resolution
/// are application behavior; this adapter cannot make those operations atomic.
typedef GoRouterStackWriter = FutureOr<void> Function(
  GoRouter router,
  List<NavigationEntry> entries,
);

/// Clears the application's navigation state using its chosen GoRouter policy.
typedef GoRouterStackClearer = FutureOr<void> Function(GoRouter router);

/// Optional bridge between GoRouter and Continuum's router-neutral recovery.
///
/// This package deliberately does not inspect GoRouter's internal route-match
/// tree or serialize [GoRouterState.extra]. The application owns the mapping
/// between GoRouter routes and [NavigationEntry] values, including nested
/// routes, ShellRoute/StatefulShellRoute branches, guards and redirects.
///
/// The supplied reader must return the complete logical stack, not merely the
/// currently visible route. The writer must reconstruct the intended stack
/// using public GoRouter APIs and application-owned route definitions. Since
/// GoRouter navigation can invoke redirects or guards, rollback/atomicity is
/// the writer's responsibility and cannot be guaranteed by this adapter.
///
/// The adapter does not own or dispose [router].
class GoRouterNavigationAdapter implements NavigationStatePort {
  GoRouterNavigationAdapter({
    required GoRouter router,
    required GoRouterStackReader readStack,
    required GoRouterStackWriter writeStack,
    required GoRouterStackClearer clearStack,
  })  : _router = router,
        _readStack = readStack,
        _writeStack = writeStack,
        _clearStack = clearStack;

  final GoRouter _router;
  final GoRouterStackReader _readStack;
  final GoRouterStackWriter _writeStack;
  final GoRouterStackClearer _clearStack;
  bool _disposed = false;

  /// Releases this adapter's access to the router without disposing the router.
  void dispose() {
    _disposed = true;
  }

  @override
  Future<List<NavigationEntry>> captureStack() async {
    _ensureActive();
    final entries = await _readStack(_router);
    return List<NavigationEntry>.unmodifiable(
      entries.map(_copyEntry),
    );
  }

  @override
  Future<void> replaceStack(List<NavigationEntry> entries) async {
    _ensureActive();
    final safeEntries = List<NavigationEntry>.unmodifiable(
      entries.map(_copyEntry),
    );
    await _writeStack(_router, safeEntries);
  }

  @override
  Future<void> clearStack() async {
    _ensureActive();
    await _clearStack(_router);
  }

  NavigationEntry _copyEntry(NavigationEntry entry) => NavigationEntry(
        routeId: entry.routeId,
        parameters: entry.parameters,
      );

  void _ensureActive() {
    if (_disposed) {
      throw StateError('GoRouterNavigationAdapter has been disposed.');
    }
  }
}
