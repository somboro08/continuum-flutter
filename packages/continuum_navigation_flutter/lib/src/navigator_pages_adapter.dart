import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';

import 'navigation_page_registry.dart';

/// Bridges Continuum's router-neutral navigation port to Flutter's
/// declarative [Navigator.pages] API.
///
/// The adapter owns only a serializable list of [NavigationEntry] values and
/// the corresponding immutable [Page] list. It does not own a Navigator,
/// GlobalKey, BuildContext, route controller, or application widget tree.
///
/// Supply [pages] to [Navigator.pages] and [handlePageRemoved] to
/// [Navigator.onDidRemovePage]. The host application remains responsible for
/// creating and owning its Navigator widget.
class NavigatorPagesAdapter extends ChangeNotifier
    implements NavigationStatePort {
  NavigatorPagesAdapter({
    required NavigationPageRegistry pageRegistry,
    List<NavigationEntry> initialEntries = const <NavigationEntry>[],
  })  : _pageRegistry = pageRegistry,
        _entries = List<NavigationEntry>.unmodifiable(initialEntries) {
    _pages = _buildPages(_entries);
  }

  final NavigationPageRegistry _pageRegistry;
  List<NavigationEntry> _entries;
  late List<Page<dynamic>> _pages;
  bool _disposed = false;

  /// Current immutable declarative page list for Navigator(pages: ...).
  List<Page<dynamic>> get pages => _pages;

  /// Current immutable router-neutral stack.
  List<NavigationEntry> get entries => _entries;

  @override
  Future<List<NavigationEntry>> captureStack() async {
    _ensureNotDisposed();
    return List<NavigationEntry>.unmodifiable(_entries);
  }

  /// Builds and validates the entire target page list before publishing it.
  ///
  /// If a route factory throws, a route is missing, or page keys collide, the
  /// existing stack and visible page list remain unchanged.
  @override
  Future<void> replaceStack(List<NavigationEntry> entries) async {
    _ensureNotDisposed();
    final nextEntries = List<NavigationEntry>.unmodifiable(entries);
    final nextPages = _buildPages(nextEntries);

    // These assignments are synchronous and happen only after every factory
    // has succeeded, so observers never see a partially replaced stack.
    _entries = nextEntries;
    _pages = nextPages;
    notifyListeners();
  }

  @override
  Future<void> clearStack() async {
    _ensureNotDisposed();
    if (_entries.isEmpty) return;
    _entries = const <NavigationEntry>[];
    _pages = const <Page<dynamic>>[];
    notifyListeners();
  }

  /// Reconciles a user-driven Navigator pop with the adapter's source of truth.
  ///
  /// Pass this method directly as Navigator.onDidRemovePage. It returns false
  /// when [page] is not one of the currently published pages.
  bool handlePageRemoved(Page<Object?> page) {
    if (_disposed) return false;
    final index = _pages.indexWhere((candidate) => identical(candidate, page));
    if (index < 0) return false;

    final nextEntries = List<NavigationEntry>.of(_entries)..removeAt(index);
    final nextPages = List<Page<dynamic>>.of(_pages)..removeAt(index);
    _entries = List<NavigationEntry>.unmodifiable(nextEntries);
    _pages = List<Page<dynamic>>.unmodifiable(nextPages);
    notifyListeners();
    return true;
  }

  List<Page<dynamic>> _buildPages(List<NavigationEntry> entries) {
    final result = <Page<dynamic>>[];
    final keys = <Key>{};

    for (final entry in entries) {
      final factory = _pageRegistry[entry.routeId];
      if (factory == null) {
        throw StateError(
          'No Flutter page factory is registered for route "${entry.routeId}".',
        );
      }

      final page = factory(entry);
      if (!keys.add(page.key)) {
        throw StateError(
          'Flutter page factory for route "${entry.routeId}" produced a '
          'duplicate page key "${page.key}". Each stack occurrence needs '
          'a unique key.',
        );
      }
      result.add(page);
    }

    return List<Page<dynamic>>.unmodifiable(result);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('NavigatorPagesAdapter has been disposed.');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
