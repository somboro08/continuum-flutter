import 'package:continuum_core/continuum_core.dart';
import 'package:continuum_lifecycle/continuum_lifecycle.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterLifecycleModule', () {
    test('registers the event source and publishes lifecycle transitions',
        () async {
      final services = ContinuumServiceRegistry();
      final context = ContinuumContext(
        services: services,
        logger: const NoopContinuumLogger(),
      );
      final module = FlutterLifecycleModule();

      await module.initialize(context);
      await module.initialize(context);

      expect(services.get<LifecycleEventSource>(), same(module));

      final nextState = module.currentPhase == AppLifecyclePhase.resumed
          ? AppLifecycleState.paused
          : AppLifecycleState.resumed;
      final expectedPhase = nextState == AppLifecycleState.paused
          ? AppLifecyclePhase.paused
          : AppLifecyclePhase.resumed;
      final eventFuture = module.transitions.first;

      module.didChangeAppLifecycleState(nextState);

      final event = await eventFuture;
      expect(event.current, expectedPhase);
      expect(event.previous, isNot(expectedPhase));
      expect(module.currentPhase, expectedPhase);

      await module.dispose();
      expect(services.contains<LifecycleEventSource>(), isFalse);
    });

    test('can be initialized again after disposal with a fresh stream',
        () async {
      final services = ContinuumServiceRegistry();
      final context = ContinuumContext(
        services: services,
        logger: const NoopContinuumLogger(),
      );
      final module = FlutterLifecycleModule();

      await module.initialize(context);
      await module.dispose();
      expect(services.contains<LifecycleEventSource>(), isFalse);

      await module.initialize(context);
      expect(services.get<LifecycleEventSource>(), same(module));

      final nextState = module.currentPhase == AppLifecyclePhase.resumed
          ? AppLifecycleState.paused
          : AppLifecycleState.resumed;
      final expectedPhase = nextState == AppLifecycleState.paused
          ? AppLifecyclePhase.paused
          : AppLifecyclePhase.resumed;
      final eventFuture = module.transitions.first;

      module.didChangeAppLifecycleState(nextState);

      expect((await eventFuture).current, expectedPhase);
      await module.dispose();
      expect(services.contains<LifecycleEventSource>(), isFalse);
    });
  });
}
