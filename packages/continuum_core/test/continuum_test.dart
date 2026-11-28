import 'package:continuum_core/continuum_core.dart';
import 'package:test/test.dart';

class _Module extends ContinuumModule {
  _Module(this.id, this.order, {this.dependencies = const {}});
  @override
  final String id;
  final List<String> order;
  @override
  final Set<String> dependencies;

  @override
  Future<void> initialize(ContinuumContext context) async => order.add(id);
  @override
  Future<void> dispose() async => order.add('dispose:$id');
}

void main() {
  test('initializes dependencies before dependants and disposes in reverse', () async {
    final order = <String>[];
    final runtime = Continuum();
    runtime.install(_Module('feature', order, dependencies: {'foundation'}));
    runtime.install(_Module('foundation', order));

    await runtime.initialize();
    expect(order, ['foundation', 'feature']);
    expect(runtime.state, ContinuumRuntimeState.ready);

    await runtime.dispose();
    expect(order, ['foundation', 'feature', 'dispose:feature', 'dispose:foundation']);
    expect(runtime.state, ContinuumRuntimeState.disposed);
  });

  test('rejects a missing dependency before initializing modules', () async {
    final runtime = Continuum()..install(_Module('feature', [], dependencies: {'missing'}));
    await expectLater(runtime.initialize(), throwsStateError);
  });
}
