import 'dart:async';

import 'package:continuum_recovery/continuum_recovery.dart';
import 'package:test/test.dart';

CheckpointResult success() => const CheckpointResult(saved: ['state'], cleared: [], failed: {});

void main() {
  test('coalesces requests during debounce into one checkpoint', () async {
    var calls = 0;
    final scheduler = CheckpointScheduler(
      checkpoint: () async { calls++; return success(); },
      debounce: const Duration(milliseconds: 15),
      minimumInterval: Duration.zero,
    );
    final results = await Future.wait([
      scheduler.requestCheckpoint(),
      scheduler.requestCheckpoint(),
      scheduler.requestCheckpoint(),
    ]);
    expect(calls, 1);
    expect(results.every((result) => result.saved.single == 'state'), isTrue);
    await scheduler.dispose();
  });

  test('enforces minimum interval between automatic checkpoints', () async {
    final starts = <Duration>[];
    final clock = Stopwatch()..start();
    final scheduler = CheckpointScheduler(
      checkpoint: () async { starts.add(clock.elapsed); return success(); },
      debounce: Duration.zero,
      minimumInterval: const Duration(milliseconds: 40),
    );
    await scheduler.requestCheckpoint();
    await scheduler.requestCheckpoint();
    expect(starts, hasLength(2));
    expect(starts.last - starts.first, greaterThanOrEqualTo(const Duration(milliseconds: 35)));
    await scheduler.dispose();
  });

  test('checkpointNow bypasses debounce and throttle', () async {
    var calls = 0;
    final scheduler = CheckpointScheduler(
      checkpoint: () async { calls++; return success(); },
      debounce: const Duration(seconds: 2),
      minimumInterval: const Duration(seconds: 5),
    );
    await scheduler.checkpointNow();
    await scheduler.checkpointNow();
    expect(calls, 2);
    await scheduler.dispose();
  });

  test('requests arriving during a run trigger a second checkpoint', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var calls = 0;
    final scheduler = CheckpointScheduler(
      debounce: Duration.zero,
      minimumInterval: Duration.zero,
      checkpoint: () async {
        calls++;
        if (calls == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        }
        return success();
      },
    );
    final first = scheduler.checkpointNow();
    await firstStarted.future;
    final second = scheduler.checkpointNow();
    releaseFirst.complete();
    await Future.wait([first, second]);
    expect(calls, 2);
    await scheduler.dispose();
  });

  test('propagates checkpoint errors to every coalesced caller', () async {
    final expected = StateError('disk unavailable');
    final scheduler = CheckpointScheduler(
      debounce: const Duration(milliseconds: 5),
      checkpoint: () async => throw expected,
    );
    final first = scheduler.requestCheckpoint();
    final second = scheduler.requestCheckpoint();
    await expectLater(first, throwsA(same(expected)));
    await expectLater(second, throwsA(same(expected)));
    await scheduler.dispose();
  });

  test('flushes pending requests during disposal and rejects later requests', () async {
    var calls = 0;
    final scheduler = CheckpointScheduler(
      debounce: const Duration(seconds: 5),
      checkpoint: () async { calls++; return success(); },
    );
    final pending = scheduler.requestCheckpoint();
    await scheduler.dispose(flushPending: true);
    expect((await pending).isSuccessful, isTrue);
    expect(calls, 1);
    expect(() => scheduler.requestCheckpoint(), throwsStateError);
  });

  test('disposal without flush fails pending callers clearly', () async {
    final scheduler = CheckpointScheduler(
      debounce: const Duration(seconds: 5),
      checkpoint: () async => success(),
    );
    final pending = scheduler.requestCheckpoint();
    await scheduler.dispose();
    await expectLater(pending, throwsStateError);
  });

  test('waits for an active checkpoint during disposal', () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    final scheduler = CheckpointScheduler(
      debounce: Duration.zero,
      checkpoint: () async {
        started.complete();
        await finish.future;
        return success();
      },
    );
    final request = scheduler.checkpointNow();
    await started.future;
    var disposed = false;
    final disposal = scheduler.dispose().then((_) => disposed = true);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(disposed, isFalse);
    finish.complete();
    await disposal;
    expect(disposed, isTrue);
    expect((await request).isSuccessful, isTrue);
  });

  test('validates timing configuration', () {
    expect(
      () => CheckpointScheduler(checkpoint: () async => success(), debounce: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
    expect(
      () => CheckpointScheduler(checkpoint: () async => success(), minimumInterval: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });
}
