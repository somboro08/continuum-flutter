import 'dart:async';

import 'package:continuum_core/continuum_core.dart';
import 'package:continuum_recovery/continuum_recovery.dart';

typedef CheckpointResultHandler = void Function(CheckpointResult result, LifecycleTransition transition);
typedef CheckpointErrorHandler = void Function(Object error, StackTrace stackTrace, LifecycleTransition transition);
typedef LifecycleStreamErrorHandler = void Function(Object error, StackTrace stackTrace);
typedef BindingCallbackErrorHandler = void Function(Object error, StackTrace stackTrace);

/// Connects lifecycle observations to a checkpoint scheduler.
///
/// This adapter does not own or dispose the lifecycle source or scheduler.
/// The application owns their lifecycles and can share one scheduler between
/// multiple triggers. It never assumes a lifecycle callback runs before the
/// operating system terminates the process.
class LifecycleCheckpointBinding {
  LifecycleCheckpointBinding({
    required LifecycleEventSource lifecycle,
    required CheckpointScheduler scheduler,
    Set<AppLifecyclePhase> checkpointOn = const {
      AppLifecyclePhase.hidden,
      AppLifecyclePhase.paused,
      AppLifecyclePhase.detached,
    },
    Set<AppLifecyclePhase> immediateOn = const {
      AppLifecyclePhase.paused,
      AppLifecyclePhase.detached,
    },
    this.onCheckpointResult,
    this.onCheckpointError,
    this.onLifecycleStreamError,
    this.onCallbackError,
  })  : _lifecycle = lifecycle,
        _scheduler = scheduler,
        checkpointOn = Set.unmodifiable(checkpointOn),
        immediateOn = Set.unmodifiable(immediateOn) {
    if (!this.checkpointOn.containsAll(this.immediateOn)) {
      throw ArgumentError.value(
        immediateOn,
        'immediateOn',
        'Every immediate phase must also be included in checkpointOn.',
      );
    }
  }

  final LifecycleEventSource _lifecycle;
  final CheckpointScheduler _scheduler;
  final Set<AppLifecyclePhase> checkpointOn;
  final Set<AppLifecyclePhase> immediateOn;
  final CheckpointResultHandler? onCheckpointResult;
  final CheckpointErrorHandler? onCheckpointError;
  final LifecycleStreamErrorHandler? onLifecycleStreamError;
  final BindingCallbackErrorHandler? onCallbackError;

  StreamSubscription<LifecycleTransition>? _subscription;
  bool _disposed = false;

  bool get isStarted => _subscription != null;
  bool get isDisposed => _disposed;

  /// Starts listening once. Calling start repeatedly is safe.
  void start() {
    if (_disposed) throw StateError('LifecycleCheckpointBinding has been disposed.');
    if (_subscription != null) return;
    _subscription = _lifecycle.transitions.listen(
      _handleTransition,
      onError: (Object error, StackTrace stackTrace) {
        _invoke(() => onLifecycleStreamError?.call(error, stackTrace));
      },
    );
  }

  void _handleTransition(LifecycleTransition transition) {
    if (!checkpointOn.contains(transition.current)) return;
    try {
      final operation = immediateOn.contains(transition.current)
          ? _scheduler.checkpointNow()
          : _scheduler.requestCheckpoint();
      operation.then<void>(
        (result) => _invoke(() => onCheckpointResult?.call(result, transition)),
        onError: (Object error, StackTrace stackTrace) {
          _invoke(() => onCheckpointError?.call(error, stackTrace, transition));
        },
      );
    } catch (error, stackTrace) {
      _invoke(() => onCheckpointError?.call(error, stackTrace, transition));
    }
  }

  void _invoke(void Function() callback) {
    try {
      callback();
    } catch (error, stackTrace) {
      try {
        onCallbackError?.call(error, stackTrace);
      } catch (_) {
        // Observer callbacks must not destabilize lifecycle event delivery.
      }
    }
  }

  /// Stops listening but deliberately leaves the shared scheduler alive.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
