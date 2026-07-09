import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/incremental_backup.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late Directory sourceDirectory;
  late Directory backupDirectory;

  setUp(() async {
    testDirectory =
        await Directory.systemTemp.createTemp('mbg-incremental-backup-');
    sourceDirectory = await Directory('${testDirectory.path}/source').create();
    backupDirectory = await Directory('${testDirectory.path}/backups').create();
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('balances byte and file progress and reserves finalization time', () {
    final manyFilesRemaining = estimateBackupWork(
      elapsed: const Duration(seconds: 10),
      processedBytes: 990,
      totalBytes: 1000,
      processedFiles: 1,
      totalFiles: 100,
    );
    final allFilesWritten = estimateBackupWork(
      elapsed: const Duration(seconds: 10),
      processedBytes: 1000,
      totalBytes: 1000,
      processedFiles: 100,
      totalFiles: 100,
    );

    expect(manyFilesRemaining.progress, lessThan(0.7));
    expect(manyFilesRemaining.remaining, greaterThan(Duration.zero));
    expect(allFilesWritten.progress, _closeTo(0.97));
    expect(
      allFilesWritten.remaining,
      greaterThanOrEqualTo(const Duration(milliseconds: 1500)),
    );
  });

  test('creates only deltas after the initial backup', () async {
    final inspectionFile = await File('${sourceDirectory.path}/inspection.json')
        .writeAsString('inspection-v1');
    await Directory('${sourceDirectory.path}/images').create();
    final imageFile = await File('${sourceDirectory.path}/images/photo.jpg')
        .writeAsString('photo-v1');

    final initial = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(initial.changedFileCount, 2);
    expect(_archiveNames(initial.backupFile!), {
      'inspection.json',
      'images/photo.jpg',
      incrementalBackupManifestName,
    });

    final unchanged = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(unchanged.created, isFalse);
    expect(await listManagedLocalBackups(backupDirectory), hasLength(1));

    final newFile = await File('${sourceDirectory.path}/new-inspection.json')
        .writeAsString('inspection-v2');
    final added = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(added.changedFileCount, 1);
    expect(_archiveNames(added.backupFile!), {
      'new-inspection.json',
      incrementalBackupManifestName,
    });
    expect(
      _readManifest(added.backupFile!)['baseBackup'],
      _basename(initial.backupFile!.path),
    );

    await inspectionFile.writeAsString('inspection-v1-updated');
    await inspectionFile.setLastModified(DateTime(2026, 2, 1));
    final updated = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(updated.changedFileCount, 1);
    expect(_archiveNames(updated.backupFile!), {
      'inspection.json',
      incrementalBackupManifestName,
    });

    await imageFile.delete();
    final deleted = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(deleted.changedFileCount, 0);
    expect(deleted.deletedFileCount, 1);
    expect(_archiveNames(deleted.backupFile!), {
      incrementalBackupManifestName,
    });
    expect(
      _readManifest(deleted.backupFile!)['deletedFiles'],
      ['images/photo.jpg'],
    );
    expect(await newFile.exists(), isTrue);
    expect(await listManagedLocalBackups(backupDirectory), hasLength(4));
  });

  test('adopts the newest legacy full backup as the baseline', () async {
    final existingFile = await File('${sourceDirectory.path}/existing.json')
        .writeAsString('already backed up');
    await existingFile.setLastModified(DateTime(2026, 1, 1));
    final legacyBackup = File('${backupDirectory.path}/backup-1000.zip');
    final encoder = ZipFileEncoder();
    encoder.create(legacyBackup.path);
    await encoder.addFile(existingFile, '/existing.json');
    await encoder.close();
    await legacyBackup.setLastModified(DateTime(2026, 1, 2));

    final unchanged = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(unchanged.created, isFalse);

    await File('${sourceDirectory.path}/new.json').writeAsString('new');
    final incremental = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(_archiveNames(incremental.backupFile!), {
      'new.json',
      incrementalBackupManifestName,
    });
    expect(
      _readManifest(incremental.backupFile!)['baseBackup'],
      'backup-1000.zip',
    );
  });

  test('does not trust files missing from a legacy backup', () async {
    final archivedFile = await File('${sourceDirectory.path}/archived.json')
        .writeAsString('archived');
    final missingFile = await File('${sourceDirectory.path}/missing.json')
        .writeAsString('missing');
    final sourceTime = DateTime(2026, 1, 1);
    await archivedFile.setLastModified(sourceTime);
    await missingFile.setLastModified(sourceTime);

    final legacyBackup = File('${backupDirectory.path}/backup-1000.zip');
    final encoder = ZipFileEncoder();
    encoder.create(legacyBackup.path);
    await encoder.addFile(archivedFile, '/archived.json');
    await encoder.close();
    await legacyBackup.setLastModified(DateTime(2026, 1, 2));

    final incremental = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(_archiveNames(incremental.backupFile!), {
      'missing.json',
      incrementalBackupManifestName,
    });
  });

  test('creates a new full baseline when the backup chain is incomplete',
      () async {
    await File('${sourceDirectory.path}/first.json').writeAsString('first');
    final initial = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    await initial.backupFile!.delete();
    await File('${sourceDirectory.path}/second.json').writeAsString('second');

    final replacement = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(_archiveNames(replacement.backupFile!), {
      'first.json',
      'second.json',
      incrementalBackupManifestName,
    });
    expect(_readManifest(replacement.backupFile!)['baseBackup'], isNull);
  });

  test('recovers the incremental state from the latest backup manifest',
      () async {
    await File('${sourceDirectory.path}/first.json').writeAsString('first');
    final initial = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    await File('${backupDirectory.path}/.mbg-backup-state-v1.json').delete();
    await File('${sourceDirectory.path}/second.json').writeAsString('second');

    final replacement = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(_archiveNames(replacement.backupFile!), {
      'second.json',
      incrementalBackupManifestName,
    });
    expect(
      _readManifest(replacement.backupFile!)['baseBackup'],
      _basename(initial.backupFile!.path),
    );
  });

  test('ignores timestamp-only changes but detects same-size content changes',
      () async {
    final file =
        await File('${sourceDirectory.path}/inspection.json').writeAsString(
      'first',
    );
    await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    await file.setLastModified(DateTime(2030, 1, 1));
    final touchedOnly = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(touchedOnly.created, isFalse);
    expect(await listManagedLocalBackups(backupDirectory), hasLength(1));

    await file.writeAsString('other');
    await file.setLastModified(DateTime(2030, 1, 2));
    final contentChanged = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(contentChanged.created, isTrue);
    expect(_archiveNames(contentChanged.backupFile!), {
      'inspection.json',
      incrementalBackupManifestName,
    });
  });

  test('migrates an old timestamp-only state without duplicating files',
      () async {
    final file =
        await File('${sourceDirectory.path}/inspection.json').writeAsString(
      'unchanged inspection',
    );
    await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    final stateFile = File('${backupDirectory.path}/.mbg-backup-state-v1.json');
    final state = Map<String, dynamic>.from(
      jsonDecode(await stateFile.readAsString()) as Map,
    );
    final files = state['files'] as Map;
    for (final value in files.values) {
      (value as Map).remove('contentHash');
    }
    state['version'] = 1;
    await stateFile.writeAsString(jsonEncode(state), flush: true);
    await file.setLastModified(DateTime(2031, 1, 1));

    final migrated = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(migrated.created, isFalse);
    expect(await listManagedLocalBackups(backupDirectory), hasLength(1));
    final migratedState = Map<String, dynamic>.from(
      jsonDecode(await stateFile.readAsString()) as Map,
    );
    final migratedFiles = migratedState['files'] as Map;
    expect(
      (migratedFiles['inspection.json'] as Map)['contentHash'],
      isNotEmpty,
    );
  });

  test('does not advance the state when backup creation fails', () async {
    await File('${sourceDirectory.path}/inspection.json')
        .writeAsString('inspection');

    await expectLater(
      createIncrementalBackup(
        sourceDirectory: sourceDirectory,
        backupDirectory: backupDirectory,
        onProgress: (_) => throw StateError('simulated failure'),
      ),
      throwsStateError,
    );
    expect(await listManagedLocalBackups(backupDirectory), isEmpty);

    final retry = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(_archiveNames(retry.backupFile!), {
      'inspection.json',
      incrementalBackupManifestName,
    });
  });

  test('keeps the main isolate responsive and reports an ETA', () async {
    for (var index = 0; index < 15; index++) {
      await File('${sourceDirectory.path}/inspection-$index.json')
          .writeAsString('inspection-$index');
    }

    var eventLoopTicks = 0;
    final reports = <BackupProgress>[];
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => eventLoopTicks++,
    );

    try {
      await createIncrementalBackup(
        sourceDirectory: sourceDirectory,
        backupDirectory: backupDirectory,
        onProgress: (progress) async {
          reports.add(progress);
        },
      );
    } finally {
      timer.cancel();
    }

    expect(eventLoopTicks, greaterThan(5));
    expect(reports, isNotEmpty);
    expect(reports.every((report) => report.eta.isNotEmpty), isTrue);
    expect(reports[reports.length - 2].progress, _closeTo(0.97));
    expect(reports[reports.length - 2].currentFile, 'ZIP wird abgeschlossen');
    expect(reports.last.progress, 1.0);
    expect(reports.last.processedFiles, 15);
    expect(reports.last.totalFiles, 15);
  });

  test('shares one persistent progress state across concurrent callers',
      () async {
    for (var index = 0; index < 12; index++) {
      await File('${sourceDirectory.path}/inspection-$index.json')
          .writeAsString('inspection-$index');
    }

    final coordinator = BackupCoordinator.instance;
    final observedEtaValues = <String>[];
    var resumedUpdates = 0;
    void observeProgress() {
      if (coordinator.isRunning) {
        observedEtaValues.add(coordinator.eta);
      }
    }

    void observeAfterNavigation() {
      resumedUpdates++;
    }

    coordinator.addListener(observeProgress);
    try {
      final firstBackup = coordinator.runBackup(
        sourceDirectory: sourceDirectory,
        backupDirectory: backupDirectory,
      );
      final secondBackup = coordinator.runBackup(
        sourceDirectory: sourceDirectory,
        backupDirectory: backupDirectory,
      );

      expect(coordinator.isRunning, isTrue);
      expect(coordinator.currentFile, isNotEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      coordinator.removeListener(observeProgress);
      expect(coordinator.isRunning, isTrue);
      expect(coordinator.eta, isNotEmpty);
      coordinator.addListener(observeAfterNavigation);

      final results = await Future.wait([firstBackup, secondBackup]);

      expect(results[0].backupFile!.path, results[1].backupFile!.path);
      expect(await listManagedLocalBackups(backupDirectory), hasLength(1));
      expect(observedEtaValues, isNotEmpty);
      expect(observedEtaValues.every((eta) => eta.isNotEmpty), isTrue);
      expect(resumedUpdates, greaterThan(0));
      expect(coordinator.isRunning, isFalse);
      expect(coordinator.progress, 1.0);
    } finally {
      coordinator.removeListener(observeProgress);
      coordinator.removeListener(observeAfterNavigation);
    }
  });
}

Matcher _closeTo(double value) => closeTo(value, 0.0001);

Set<String> _archiveNames(File backup) {
  final archive = ZipDecoder().decodeBytes(backup.readAsBytesSync());
  return archive.files.map((file) => file.name).toSet();
}

Map<String, dynamic> _readManifest(File backup) {
  final archive = ZipDecoder().decodeBytes(backup.readAsBytesSync());
  final manifest = archive.files.singleWhere(
    (file) => file.name == incrementalBackupManifestName,
  );
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(manifest.content as List<int>)),
  );
}

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;
