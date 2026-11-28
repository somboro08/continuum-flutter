enum PersistenceMode { ephemeral, session, restorable, history, persistent }

class PersistencePolicy {
  const PersistencePolicy({
    required this.mode,
    this.retention,
    this.sensitive = false,
  }) : assert(mode == PersistenceMode.history || retention == null);

  final PersistenceMode mode;
  final Duration? retention;
  final bool sensitive;

  static const ephemeral = PersistencePolicy(mode: PersistenceMode.ephemeral);
  static const session = PersistencePolicy(mode: PersistenceMode.session);
  static const restorable = PersistencePolicy(mode: PersistenceMode.restorable);
  static const persistent = PersistencePolicy(mode: PersistenceMode.persistent);
  static PersistencePolicy history({Duration? retention}) =>
      PersistencePolicy(mode: PersistenceMode.history, retention: retention);
}
