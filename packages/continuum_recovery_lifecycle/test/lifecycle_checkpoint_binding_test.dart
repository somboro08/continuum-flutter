import 'dart:async';

import 'package:continuum_core/continuum_core.dart';
import 'package:continuum_recovery/continuum_recovery.dart';
import 'package:continuum_recovery_lifecycle/continuum_recovery_lifecycle.dart';
import 'package:test/test.dart';

class FakeLifecycleSource implements LifecycleEventSource {
  final controller = StreamController<LifecycleTransition>.broadcast();
  @override
  Stream<LifecycleTransition> get transitions => controller.stream;

  void emit(AppLifecyclePhase phase) {
    controller.add(LifecycleTransition(
      previous: AppLifecyclePhase.resumed,
      current: phase,
      observedAt: DateTime.now(),
    ));
  }

  Future<void> close() => controller.close();
}

CheckpointResult success() => const CheckpointResult(saved: ['app'], cleared: [], failed: {});

void main() {
  test('checkpoints configured phases and applies immediate policy', () async {
    final source = FakeLifecycleSource();
    var calls = 0;
    final scheduler = CheckpointScheduler(
      checkpoint: () async { calls++; return success(); },
      debounce: const Duration(seconds: 5),
      minimumInterval: const Duration(seconds: 5),
    );
    final binding = LifecycleCheckpointBinding(lifecycle: source, scheduler: scheduler);
    binding.start();

    source.emit(AppLifecyclePhase.resumed);
    source.emit(AppLifecyclePhase.inactive);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(calls, 0);

    source.emit(AppLifecyclePhase.paused);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(calls, 1);

    await binding.dispose();
    await scheduler.dispose();
    await source.close();
  });

  test('debounces non-immediate lifecycle phases', () async {
    final source = FakeLifecycleSource();
    var calls = 0;
    final scheduler = CheckpointScheduler(
      checkpoint: () async { calls++; return success(); },
      debounce: const Duration(milliseconds: 15),
      minimumInterval: Duration.zero,
    );
    final binding = LifecycleCheckpointBinding(
      lifecycle: source,
      scheduler: scheduler,
      checkpointOn: const {AppLifecyclePhase.hidden},
      immediateOn: const {},
    )..start();

    source.emit(AppLifecyclePhase.hidden);
    expect(calls, 0);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, 1);

    await binding.dispose();
    await scheduler.dispose();
    await source.close();
  });

  test('reports checkpoint errors without stopping event observation', () async {
    final source = FakeLifecycleSource();
    final failure = StateError('storage unavailable');
    final reported = <Object>[];
    final scheduler = CheckpointScheduler(
      checkpoint: () async => throw failure,
      debounce: Duration.zero,
      minimumInterval: Duration.zero,
    );
    final binding = LifecycleCheckpointBinding(
      lifecycle: source,
      scheduler: scheduler,
      checkpointOn: const {AppLifecyclePhase.hidden},
      immediateOn: const {AppLifecyclePhase.hidden},
      onCheckpointError: (error, _, __) => reported.add(error),
    )..start();

    source.emit(AppLifecyclePhase.hidden);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(reported, [same(failure)]);

    await binding.dispose();
    await scheduler.dispose();
    await source.close();
  });

  test('validates immediate phases are included in checkpoint phases', () async {
    final source = FakeLifecycleSource();
    final scheduler = CheckpointScheduler(checkpoint: () async => success());
    expect(
      () => LifecycleCheckpointBinding(
        lifecycle: source,
        scheduler: scheduler,
        checkpointOn: const {AppLifecyclePhase.paused},
        immediateOn: const {AppLifecyclePhase.detached},
      ),
      throwsArgumentError,
    );
    await scheduler.dispose();
    await source.close();
  });

  test('start is idempotent and disposed bindings reject restart', () async {
    final source = FakeLifecycleSource();
    var calls = 0;
    final scheduler = CheckpointScheduler(
      checkpoint: () async { calls++; return success(); },
      debounce: Duration.zero,
      minimumInterval: Duration.zero,
    );
    final binding = LifecycleCheckpointBinding(
      lifecycle: source,
      scheduler: scheduler,
      checkpointOn: const {AppLifecyclePhase.paused},
      immediateOn: const {AppLifecyclePhase.paused},
    );
    binding.start();
    binding.start();
    source.emit(AppLifecyclePhase.paused);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(calls, 1);
    await binding.dispose();
    expect(() => binding.start(), throwsStateError);
    await scheduler.dispose();
    await source.close();
  });
}
