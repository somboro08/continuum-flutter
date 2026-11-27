import 'lifecycle_transition.dart';

abstract interface class LifecycleEventSource {
  Stream<LifecycleTransition> get transitions;
}
