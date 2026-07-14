import 'package:flutter/foundation.dart';

class BackupSyncWorkflowGuard {
  BackupSyncWorkflowGuard({
    this.startupGrace = const Duration(seconds: 30),
  });

  static final BackupSyncWorkflowGuard instance = BackupSyncWorkflowGuard();

  final Duration startupGrace;
  Object? _activeToken;
  DateTime? _startedAt;

  Object? tryAcquire({
    required bool backupRunning,
    required bool syncRunning,
    required bool analyzing,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final activeToken = _activeToken;
    if (activeToken != null) {
      final startedAt = _startedAt;
      final withinStartupGrace =
          startedAt != null && currentTime.difference(startedAt) < startupGrace;
      if (backupRunning || syncRunning || analyzing || withinStartupGrace) {
        return null;
      }
      _activeToken = null;
      _startedAt = null;
    } else if (backupRunning || analyzing) {
      return null;
    }

    final token = Object();
    _activeToken = token;
    _startedAt = currentTime;
    return token;
  }

  void release(Object token) {
    if (!identical(_activeToken, token)) return;
    _activeToken = null;
    _startedAt = null;
  }

  @visibleForTesting
  void reset() {
    _activeToken = null;
    _startedAt = null;
  }
}
