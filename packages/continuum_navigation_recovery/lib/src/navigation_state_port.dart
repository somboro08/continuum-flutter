import 'navigation_entry.dart';

/// Adapter implemented by the host application's router/navigation layer.
///
/// [replaceStack] should validate/build the complete target stack before
/// replacing the visible stack, so a failed restore does not leave a partial
/// navigation state on screen.
abstract interface class NavigationStatePort {
  Future<List<NavigationEntry>> captureStack();

  Future<void> replaceStack(List<NavigationEntry> entries);

  Future<void> clearStack();
}
