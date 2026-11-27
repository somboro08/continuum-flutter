import 'app_lifecycle_phase.dart';

class LifecycleTransition {
  const LifecycleTransition({
    required this.previous,
    required this.current,
    required this.observedAt,
  });
  final AppLifecyclePhase previous;
  final AppLifecyclePhase current;
  final DateTime observedAt;
}
