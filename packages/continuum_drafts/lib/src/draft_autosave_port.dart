import 'package:continuum_recovery/continuum_recovery.dart';

/// Internal seam that lets draft sessions request coalesced checkpoints.
abstract interface class DraftAutosavePort {
  bool get isDisposed;
  Future<CheckpointResult> requestCheckpoint();
  Future<CheckpointResult> checkpointNow();
}
