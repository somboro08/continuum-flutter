import 'continuum_context.dart';
import 'continuum_module.dart';
import 'continuum_service_registry.dart';

enum ContinuumRuntimeState { configuring, initializing, ready, disposing, disposed, failed }

/// Composes modules without owning the app router, state manager or storage engine.
class Continuum {
  Continuum({ContinuumServiceRegistry? services, ContinuumLogger logger = const NoopContinuumLogger()})
      : services = services ?? ContinuumServiceRegistry(),
        logger = logger;

  final ContinuumServiceRegistry services;
  final ContinuumLogger logger;
  final Map<String, ContinuumModule> _modules = {};
  final List<ContinuumModule> _initialized = [];
  ContinuumRuntimeState _state = ContinuumRuntimeState.configuring;

  ContinuumRuntimeState get state => _state;
  List<String> get moduleIds => List.unmodifiable(_modules.keys);

  void install(ContinuumModule module) {
    if (_state != ContinuumRuntimeState.configuring) {
      throw StateError('Modules can only be installed before initialization.');
    }
    if (module.id.trim().isEmpty) throw ArgumentError.value(module.id, 'module.id');
    if (_modules.containsKey(module.id)) throw StateError('Module "${module.id}" already installed.');
    _modules[module.id] = module;
  }

  Future<void> initialize() async {
    if (_state != ContinuumRuntimeState.configuring) throw StateError('Runtime already initialized.');
    final ordered = _resolveOrder();
    _state = ContinuumRuntimeState.initializing;
    final context = ContinuumContext(services: services, logger: logger);
    try {
      for (final module in ordered) {
        logger.debug('Initializing "${module.id}".');
        await module.initialize(context);
        _initialized.add(module);
      }
      _state = ContinuumRuntimeState.ready;
      logger.info('Continuum ready: ${_initialized.length} module(s).');
    } catch (error, stackTrace) {
      logger.error('Initialization failed.', error: error, stackTrace: stackTrace);
      await _disposeInitialized();
      _state = ContinuumRuntimeState.failed;
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_state == ContinuumRuntimeState.disposed || _state == ContinuumRuntimeState.disposing) return;
    _state = ContinuumRuntimeState.disposing;
    await _disposeInitialized();
    _state = ContinuumRuntimeState.disposed;
  }

  List<ContinuumModule> _resolveOrder() {
    final ordered = <ContinuumModule>[];
    final visiting = <String>{};
    final visited = <String>{};
    void visit(String id) {
      if (visited.contains(id)) return;
      if (!visiting.add(id)) throw StateError('Circular dependency at "$id".');
      final module = _modules[id];
      if (module == null) throw StateError('Required module "$id" is not installed.');
      for (final dependency in module.dependencies) {
        if (!_modules.containsKey(dependency)) {
          throw StateError('Module "$id" requires missing module "$dependency".');
        }
        visit(dependency);
      }
      visiting.remove(id);
      visited.add(id);
      ordered.add(module);
    }
    for (final id in _modules.keys) {
      visit(id);
    }
    return ordered;
  }

  Future<void> _disposeInitialized() async {
    for (final module in _initialized.reversed.toList()) {
      try {
        await module.dispose();
      } catch (error, stackTrace) {
        logger.error('Dispose failed for "${module.id}".', error: error, stackTrace: stackTrace);
      }
    }
    _initialized.clear();
  }
}
