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

  test('ignores runtime and operational files when they change', () async {
    final inspection = await File('${sourceDirectory.path}/inspection.data')
        .writeAsString('inspection-v1');
    final failedRequest = await File(
      '${sourceDirectory.path}/failed-requests/request-1',
    ).create(recursive: true);
    final skippedRequest = await File(
      '${sourceDirectory.path}/skipped-requests/request-1',
    ).create(recursive: true);
    final imageIndex = await File(
      '${sourceDirectory.path}/image-index/hash-1',
    ).create(recursive: true);
    final option = await File(
      '${sourceDirectory.path}/other/options',
    ).create(recursive: true);
    final syncMap = await File(
      '${sourceDirectory.path}/other/__sync_maps__6000001',
    ).create(recursive: true);
    final runtimeAsset = await File(
      '${sourceDirectory.path}/flutter_assets/AssetManifest.bin',
    ).create(recursive: true);
    await failedRequest.writeAsString('failed-v1');
    await skippedRequest.writeAsString('skipped-v1');
    await imageIndex.writeAsString('index-v1');
    await option.writeAsString('option-v1');
    await syncMap.writeAsString('map-v1');
    await runtimeAsset.writeAsString('asset-v1');

    final initial = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(_archiveNames(initial.backupFile!), {
      'inspection.data',
      incrementalBackupManifestName,
    });

    await failedRequest.writeAsString('failed-v2');
    await skippedRequest.writeAsString('skipped-v2');
    await imageIndex.writeAsString('index-v2');
    await option.writeAsString('option-v2');
    await syncMap.writeAsString('map-v2');
    await runtimeAsset.writeAsString('asset-v2');

    final unchanged = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(unchanged.created, isFalse);
    expect(await listManagedLocalBackups(backupDirectory), hasLength(1));
    expect(await inspection.exists(), isTrue);
  });

  test('cleans up abandoned managed partial archives', () async {
    final abandoned = await File(
      '${backupDirectory.path}/backup-123.zip.partial',
    ).writeAsString('incomplete');
    final unrelated = await File(
      '${backupDirectory.path}/manual-export.zip.partial',
    ).writeAsString('keep me');
    await File('${sourceDirectory.path}/inspection.data')
        .writeAsString('inspection');

    final result = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    expect(result.created, isTrue);
    expect(await abandoned.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });

  test('does not back up records again after sync assigns E numbers', () async {
    const inspectionId = '6006395-undefined-undefined-undefined';
    const localCategoryId = '__local_category';
    const localCheckpointId = '__local_checkpoint';
    const serverCategoryId = '6006395-4-undefined-undefined';
    const serverCheckpointId = '6006395-4-9-undefined';
    const originalImagePath = '6006395-4-9--1/14_07_2026_12_20_11.jpg';
    const temporaryUploadPath = '6006395-4-9-0/14_07_2026_12_20_11.jpg';

    await Directory('${sourceDirectory.path}/root').create();
    await Directory('${sourceDirectory.path}/$inspectionId').create();
    await Directory('${sourceDirectory.path}/$localCategoryId').create();
    await Directory('${sourceDirectory.path}/failed-requests').create();
    await Directory('${sourceDirectory.path}/image-index').create();
    await File('${sourceDirectory.path}/root/$inspectionId').writeAsString(
      jsonEncode({
        'PjNr': 6006395,
        'StONr': 34569,
        'PjName': 'Müggelschlößchenweg',
        'local_id': inspectionId,
      }),
    );
    final localCategory = File(
      '${sourceDirectory.path}/$inspectionId/$localCategoryId',
    );
    await localCategory.writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': -1,
      'KurzText': 'Weg zum Mast',
      'local_id': localCategoryId,
      'parent_local_id': inspectionId,
      'offline': true,
    }));
    final localCheckpoint = File(
      '${sourceDirectory.path}/$localCategoryId/$localCheckpointId',
    );
    await localCheckpoint.writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': -1,
      'E2': -1,
      'KurzText': 'Kennzeichnung Zuwegung',
      'local_id': localCheckpointId,
      'parent_local_id': localCategoryId,
      'offline': true,
    }));
    await File('${sourceDirectory.path}/failed-requests/request-1')
        .writeAsString('pending sync request');
    await File('${sourceDirectory.path}/image-index/local-image')
        .writeAsString('temporary image mapping');
    await File('${sourceDirectory.path}/$originalImagePath')
        .create(recursive: true)
        .then((file) => file.writeAsBytes([1, 2, 3, 4]));
    await File('${sourceDirectory.path}/$temporaryUploadPath')
        .create(recursive: true)
        .then((file) => file.writeAsBytes([1, 2, 3, 4]));

    final initialBackup = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    expect(
      _archiveNames(initialBackup.backupFile!),
      isNot(contains('failed-requests/request-1')),
    );
    expect(
      _archiveNames(initialBackup.backupFile!),
      isNot(contains('image-index/local-image')),
    );
    final legacyStateFile =
        File('${backupDirectory.path}/.mbg-backup-state-v1.json');
    final legacyState = Map<String, dynamic>.from(
      jsonDecode(await legacyStateFile.readAsString()) as Map,
    );
    for (final value in (legacyState['files'] as Map).values) {
      (value as Map).remove('comparisonHash');
      value.remove('metadata');
    }
    legacyState['version'] = 2;
    await legacyStateFile.writeAsString(jsonEncode(legacyState), flush: true);

    final serverCategory = File(
      '${sourceDirectory.path}/$inspectionId/$serverCategoryId',
    );
    await serverCategory.writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': 4,
      'E2': null,
      'E3': null,
      'KurzText': 'Weg zum Mast',
      'local_id': serverCategoryId,
      'parent_local_id': inspectionId,
      'offline': false,
    }));
    await localCategory.delete();
    await Directory('${sourceDirectory.path}/$serverCategoryId').create();
    final serverCheckpoint = File(
      '${sourceDirectory.path}/$serverCategoryId/$serverCheckpointId',
    );
    await serverCheckpoint.writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': 4,
      'E2': 9,
      'E3': null,
      'KurzText': 'Kennzeichnung Zuwegung',
      'local_id': serverCheckpointId,
      'parent_local_id': serverCategoryId,
      'offline': false,
    }));
    await localCheckpoint.delete();
    await Directory('${sourceDirectory.path}/$localCategoryId')
        .delete(recursive: true);
    await Directory('${sourceDirectory.path}/other').create();
    await File('${sourceDirectory.path}/other/__sync_maps__6006395')
        .writeAsString(jsonEncode({
      'localIdMap': {
        localCategoryId: serverCategoryId,
        localCheckpointId: serverCheckpointId,
      },
    }));
    await Directory('${sourceDirectory.path}/failed-requests')
        .delete(recursive: true);
    await Directory('${sourceDirectory.path}/image-index')
        .delete(recursive: true);
    await File('${sourceDirectory.path}/$temporaryUploadPath').delete();

    final afterSync = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    expect(afterSync.backupFile, isNull);
    expect(afterSync.changedFileCount, 0);
    expect(afterSync.deletedFileCount, 0);
    expect(await listManagedLocalBackups(backupDirectory), hasLength(1));

    final state = Map<String, dynamic>.from(jsonDecode(
      await File('${backupDirectory.path}/.mbg-backup-state-v1.json')
          .readAsString(),
    ) as Map);
    expect(state['pendingMovedFiles'], {
      '$inspectionId/$localCategoryId': '$inspectionId/$serverCategoryId',
      '$localCategoryId/$localCheckpointId':
          '$serverCategoryId/$serverCheckpointId',
      temporaryUploadPath: originalImagePath,
    });

    await serverCheckpoint.writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': 4,
      'E2': 9,
      'E3': null,
      'KurzText': 'Kennzeichnung Zuwegung',
      'LangText': 'Tatsächlich geändert',
      'local_id': serverCheckpointId,
      'parent_local_id': serverCategoryId,
      'offline': false,
    }));
    final afterRealChange = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final manifest = _readManifest(afterRealChange.backupFile!);

    expect(manifest['changedFiles'], [
      '$serverCategoryId/$serverCheckpointId',
    ]);
    expect(manifest['movedFiles'], {
      '$inspectionId/$localCategoryId': '$inspectionId/$serverCategoryId',
      '$localCategoryId/$localCheckpointId':
          '$serverCategoryId/$serverCheckpointId',
      temporaryUploadPath: originalImagePath,
    });
  });

  test('adds readable named folders and keeps E numbers in the index',
      () async {
    const inspectionId = '6006395-undefined-undefined-undefined';
    const categoryId = '6006395-4-undefined-undefined';
    const checkpointId = '6006395-4-9-undefined';
    await Directory('${sourceDirectory.path}/root').create();
    await Directory('${sourceDirectory.path}/$inspectionId').create();
    await Directory('${sourceDirectory.path}/$categoryId').create();
    await File('${sourceDirectory.path}/root/$inspectionId').writeAsString(
      jsonEncode({
        'PjNr': 6006395,
        'StONr': 34569,
        'PjName': 'Müggelschlößchenweg',
        'local_id': inspectionId,
      }),
    );
    await File('${sourceDirectory.path}/$inspectionId/$categoryId')
        .writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': 4,
      'E2': null,
      'E3': null,
      'KurzText': 'Weg zum Mast',
      'local_id': categoryId,
      'parent_local_id': inspectionId,
    }));
    await File('${sourceDirectory.path}/$categoryId/$checkpointId')
        .writeAsString(jsonEncode({
      'PjNr': 6006395,
      'E1': 4,
      'E2': 9,
      'E3': null,
      'KurzText': 'Kennzeichnung Zuwegung',
      'local_id': checkpointId,
      'parent_local_id': categoryId,
    }));

    final backup = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final names = _archiveNames(backup.backupFile!);
    final index = _readJsonArchiveFile(
      backup.backupFile!,
      backupContentsIndexName,
    );

    expect(
      names,
      contains(
        'Backup-Struktur/Müggelschlößchenweg/Weg zum Mast/'
        'Kennzeichnung Zuwegung/',
      ),
    );
    final entries = index['Einträge'] as List;
    final checkpoint = entries.cast<Map>().singleWhere(
          (entry) => entry['Name'] == 'Kennzeichnung Zuwegung',
        );
    expect(checkpoint['E1'], 4);
    expect(checkpoint['E2'], 9);
    expect(
      checkpoint['LesbarerOrdner'],
      'Backup-Struktur/Müggelschlößchenweg/Weg zum Mast/'
      'Kennzeichnung Zuwegung',
    );
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
  return _readJsonArchiveFile(backup, incrementalBackupManifestName);
}

Map<String, dynamic> _readJsonArchiveFile(File backup, String name) {
  final archive = ZipDecoder().decodeBytes(backup.readAsBytesSync());
  final manifest = archive.files.singleWhere(
    (file) => file.name == name,
  );
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(manifest.content as List<int>)),
  );
}

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;
