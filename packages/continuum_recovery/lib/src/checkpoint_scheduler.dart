import 'dart:async';

import 'recovery_coordinator.dart';

/// Coalesces frequent checkpoint requests and enforces a minimum interval
/// between checkpoint starts.
///
/// Requests made during the debounce window share one checkpoint. Requests
/// arriving while a checkpoint is running are held for a subsequent run.
class CheckpointScheduler {
  CheckpointScheduler({
    required Future<CheckpointResult> Function() checkpoint,
    this.debounce = const Duration(milliseconds: 350),
    this.minimumInterval = const Duration(seconds: 2),
  }) : _checkpoint = checkpoint {
    if (debounce.isNegative) {
      throw ArgumentError.value(debounce, 'debounce', 'Must not be negative.');
    }
    if (minimumInterval.isNegative) {
      throw ArgumentError.value(minimumInterval, 'minimumInterval', 'Must not be negative.');
    }
  }

  final Future<CheckpointResult> Function() _checkpoint;
  final Duration debounce;
  final Duration minimumInterval;
  final Stopwatch _clock = Stopwatch()..start();
  final List<Completer<CheckpointResult>> _waiters = [];
  Timer? _debounceTimer;
  Timer? _throttleTimer;
  Future<void>? _running;
  Duration? _lastStartedAt;
  bool _disposed = false;
  bool _forcePending = false;

  bool get isDisposed => _disposed;
  bool get isRunning => _running != null;
  bool get hasPendingRequests => _waiters.isNotEmpty;

  /// Multiple requests inside the debounce window share the same result.
  Future<CheckpointResult> requestCheckpoint() {
    _ensureActive();
    final completer = Completer<CheckpointResult>();
    _waiters.add(completer);
    _scheduleDebounce();
    return completer.future;
  }

  /// Runs immediately, bypassing debounce and throttle. If another checkpoint
  /// is active, this request is queued for a subsequent run.
  Future<CheckpointResult> checkpointNow() {
    _ensureActive();
    final completer = Completer<CheckpointResult>();
    _waiters.add(completer);
    _forcePending = true;
    _cancelTimers();
    _tryRun(ignoreThrottle: true);
    return completer.future;
  }

  /// Stops accepting requests. Pending work is either flushed or rejected.
  /// An already-running checkpoint is always awaited.
  Future<void> dispose({bool flushPending = false}) async {
    if (_disposed) {
      await _running;
      return;
    }
    _disposed = true;
    _cancelTimers();
    if (flushPending && _waiters.isNotEmpty) {
      _tryRun(ignoreThrottle: true);
    } else if (_waiters.isNotEmpty) {
      final error = StateError('Checkpoint scheduler disposed before pending requests ran.');
      for (final waiter in _waiters) {
        if (!waiter.isCompleted) waiter.completeError(error, StackTrace.current);
      }
      _waiters.clear();
    }
    await _running;
  }

  void _ensureActive() {
    if (_disposed) throw StateError('CheckpointScheduler has been disposed.');
  }

  void _scheduleDebounce() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _debounceTimer = null;
      _tryRun();
    });
  }

  void _tryRun({bool ignoreThrottle = false}) {
    if (_waiters.isEmpty || _running != null) return;
    final bypassThrottle = ignoreThrottle || _forcePending;
    if (!bypassThrottle && _lastStartedAt != null) {
      final elapsed = _clock.elapsed - _lastStartedAt!;
      final remaining = minimumInterval - elapsed;
      if (remaining > Duration.zero) {
        _throttleTimer?.cancel();
        _throttleTimer = Timer(remaining, () {
          _throttleTimer = null;
          _tryRun();
        });
        return;
      }
    }

    _cancelTimers();
    final batch = List<Completer<CheckpointResult>>.of(_waiters);
    _waiters.clear();
    _lastStartedAt = _clock.elapsed;
    _forcePending = false;
    _running = _runBatch(batch);
    _running!.whenComplete(() {
      _running = null;
      if (_waiters.isNotEmpty) _tryRun(ignoreThrottle: _disposed);
    });
  }

  Future<void> _runBatch(List<Completer<CheckpointResult>> batch) async {
    try {
      final result = await _checkpoint();
      for (final waiter in batch) {
        if (!waiter.isCompleted) waiter.complete(result);
      }
    } catch (error, stackTrace) {
      for (final waiter in batch) {
        if (!waiter.isCompleted) waiter.completeError(error, stackTrace);
      }
      // Each requesting caller receives the original failure and stack trace.
    }
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }
}
