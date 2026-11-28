import 'continuum_service_registry.dart';

class ContinuumContext {
  const ContinuumContext({required this.services, required this.logger});
  final ContinuumServiceRegistry services;
  final ContinuumLogger logger;
}

abstract interface class ContinuumLogger {
  void debug(String message, {Object? error, StackTrace? stackTrace});
  void info(String message);
  void warning(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
}

class NoopContinuumLogger implements ContinuumLogger {
  const NoopContinuumLogger();
  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {}
  @override
  void info(String message) {}
  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {}
  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}
}
