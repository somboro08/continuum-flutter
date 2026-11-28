import 'package:flutter/widgets.dart';

import 'package:continuum_navigation_recovery/continuum_navigation_recovery.dart';

import 'navigation_page_registry.dart';

/// Bridges Continuum's router-neutral navigation port to Flutter's
/// declarative [Navigator.pages] API.
///
/// The adapter owns only serializable navigation entries and their immutable
/// Flutter page projection. The host application owns the Navigator widget.
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

  /// Builds and validates the complete target page list before publishing it.
  ///
  /// A missing factory, factory error, null key or duplicate key leaves the
  /// existing stack untouched.
  @override
  Future<void> replaceStack(List<NavigationEntry> entries) async {
    _ensureNotDisposed();
    final nextEntries = List<NavigationEntry>.unmodifiable(entries);
    final nextPages = _buildPages(nextEntries);

    // Publish only after every factory and key has been validated.
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
  /// Pass this method to Navigator.onDidRemovePage. It returns false when
  /// [page] is not one of the currently published pages.
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
      final pageKey = page.key;
      if (pageKey == null) {
        throw StateError(
          'Flutter page factory for route "${entry.routeId}" returned a '
          'page without a key. Every page in a recoverable stack must have '
          'a stable, unique key.',
        );
      }
      if (!keys.add(pageKey)) {
        throw StateError(
          'Flutter page factory for route "${entry.routeId}" produced a '
          'duplicate page key "$pageKey". Each stack occurrence needs '
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
