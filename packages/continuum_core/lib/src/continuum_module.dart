import 'continuum_context.dart';

/// A capability installed in a [Continuum] runtime.
abstract class ContinuumModule {
  const ContinuumModule();
  String get id;
  Set<String> get dependencies => const <String>{};
  Future<void> initialize(ContinuumContext context);
  Future<void> dispose();
}
