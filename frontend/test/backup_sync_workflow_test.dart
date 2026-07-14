import 'package:MBG_Inspektionen/backend/backup_sync_workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BackupSyncWorkflowGuard guard;
  final startedAt = DateTime(2026, 7, 14, 12);

  setUp(() {
    guard = BackupSyncWorkflowGuard(
      startupGrace: const Duration(seconds: 30),
    );
  });

  test('blocks a second workflow during startup', () {
    final first = guard.tryAcquire(
      backupRunning: false,
      syncRunning: false,
      analyzing: false,
      now: startedAt,
    );
    final second = guard.tryAcquire(
      backupRunning: false,
      syncRunning: false,
      analyzing: false,
      now: startedAt.add(const Duration(seconds: 5)),
    );

    expect(first, isNotNull);
    expect(second, isNull);
  });

  test('replaces a stale workflow lock when nothing is running', () {
    final stale = guard.tryAcquire(
      backupRunning: false,
      syncRunning: false,
      analyzing: false,
      now: startedAt,
    );
    final replacement = guard.tryAcquire(
      backupRunning: false,
      syncRunning: false,
      analyzing: false,
      now: startedAt.add(const Duration(minutes: 1)),
    );

    expect(stale, isNotNull);
    expect(replacement, isNotNull);
    expect(identical(stale, replacement), isFalse);
  });

  test('keeps the lock while backup or sync is actually running', () {
    guard.tryAcquire(
      backupRunning: false,
      syncRunning: false,
      analyzing: false,
      now: startedAt,
    );

    expect(
      guard.tryAcquire(
        backupRunning: false,
        syncRunning: true,
        analyzing: false,
        now: startedAt.add(const Duration(minutes: 1)),
      ),
      isNull,
    );
  });

  test('a stale persisted sync flag cannot block a fresh runtime', () {
    expect(
      guard.tryAcquire(
        backupRunning: false,
        syncRunning: true,
        analyzing: false,
        now: startedAt,
      ),
      isNotNull,
    );
  });
}
