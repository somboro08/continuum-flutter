import 'dart:async';
import 'package:continuum_core/continuum_core.dart';
import 'package:flutter/widgets.dart';

/// Observes Flutter lifecycle changes; it never attempts to keep the process alive.
class FlutterLifecycleModule extends ContinuumModule
    with WidgetsBindingObserver
    implements LifecycleEventSource {
  FlutterLifecycleModule();

  static const moduleId = 'continuum.lifecycle';
  final _controller = StreamController<LifecycleTransition>.broadcast();
  AppLifecyclePhase _current = AppLifecyclePhase.unknown;
  ContinuumServiceRegistry? _services;
  bool _initialized = false;

  @override
  String get id => moduleId;
  @override
  Stream<LifecycleTransition> get transitions => _controller.stream;
  AppLifecyclePhase get currentPhase => _current;

  @override
  Future<void> initialize(ContinuumContext context) async {
    if (_initialized) return;
    // Register first so duplicate service registration fails before observer
    // resources are allocated.
    context.services.register<LifecycleEventSource>(this);
    _services = context.services;
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
    final initial = WidgetsBinding.instance.lifecycleState;
    if (initial != null) _emit(_map(initial));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _emit(_map(state));

  void _emit(AppLifecyclePhase next) {
    if (next == _current) return;
    final event = LifecycleTransition(previous: _current, current: next, observedAt: DateTime.now());
    _current = next;
    if (!_controller.isClosed) _controller.add(event);
  }

  AppLifecyclePhase _map(AppLifecycleState state) => switch (state) {
    AppLifecycleState.resumed => AppLifecyclePhase.resumed,
    AppLifecycleState.inactive => AppLifecyclePhase.inactive,
    AppLifecycleState.hidden => AppLifecyclePhase.hidden,
    AppLifecycleState.paused => AppLifecyclePhase.paused,
    AppLifecycleState.detached => AppLifecyclePhase.detached,
  };

  @override
  Future<void> dispose() async {
    if (!_initialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _services?.unregister<LifecycleEventSource>();
    _services = null;
    _initialized = false;
    if (!_controller.isClosed) await _controller.close();
  }
}
