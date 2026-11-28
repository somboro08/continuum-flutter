/// A feature owns its snapshot format, validation and migration strategy.
abstract interface class RecoveryParticipant {
  String get recoveryId;
  Future<String?> createSnapshot();
  Future<void> restoreSnapshot(String snapshot);
  Future<void> clearRecoveredState();
}
