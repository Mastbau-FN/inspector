import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/backup_restore.dart';
import 'package:MBG_Inspektionen/backend/incremental_backup.dart';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;
  late Directory sourceDirectory;
  late Directory backupDirectory;
  late Directory targetDirectory;
  late Directory workingDirectory;

  setUp(() async {
    testDirectory =
        await Directory.systemTemp.createTemp('mbg-backup-restore-');
    sourceDirectory = await Directory('${testDirectory.path}/source').create();
    backupDirectory = await Directory('${testDirectory.path}/backups').create();
    targetDirectory = await Directory('${testDirectory.path}/target').create();
    workingDirectory =
        await Directory('${testDirectory.path}/working').create();
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('reconstructs a complete incremental chain transactionally', () async {
    final inspection = await File('${sourceDirectory.path}/root/inspection-1')
        .create(recursive: true);
    await inspection.writeAsString(jsonEncode({
      'PjNr': 1,
      'PjName': 'Inspektion v1',
      'local_id': 'inspection-1',
    }));
    final oldPhoto = await File('${sourceDirectory.path}/images/photo.jpg')
        .create(recursive: true);
    await oldPhoto.writeAsBytes([1, 2, 3, 4]);

    final initial = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    await inspection.writeAsString(jsonEncode({
      'PjNr': 1,
      'PjName': 'Inspektion v2',
      'local_id': 'inspection-1',
    }));
    await oldPhoto.delete();
    await File('${sourceDirectory.path}/documents/report.pdf')
        .create(recursive: true)
        .then((file) => file.writeAsBytes([9, 8, 7]));
    final delta = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    await File('${targetDirectory.path}/obsolete/data')
        .create(recursive: true)
        .then((file) => file.writeAsString('remove me'));
    await File('${targetDirectory.path}/failed-requests/pending')
        .create(recursive: true)
        .then((file) => file.writeAsString('do not keep'));
    await File('${targetDirectory.path}/other/options')
        .create(recursive: true)
        .then((file) => file.writeAsString('keep settings'));
    await File('${targetDirectory.path}/other/__sync_maps__1')
        .create(recursive: true)
        .then((file) => file.writeAsString('stale map'));
    await File('${targetDirectory.path}/flutter_assets/runtime')
        .create(recursive: true)
        .then((file) => file.writeAsString('keep runtime'));

    final selected = [delta.backupFile!, initial.backupFile!];
    final preview = await inspectIncrementalBackupChain(selected);

    expect(preview.chainLength, 2);
    expect(preview.fileCount, 2);
    expect(preview.ignoredBackupCount, 0);

    final result = await restoreIncrementalBackupChain(
      backupFiles: selected,
      targetDirectory: targetDirectory,
      workingDirectory: workingDirectory,
    );

    expect(result.appliedBackupCount, 2);
    expect(result.restoredFileCount, 2);
    expect(
      jsonDecode(
        await File('${targetDirectory.path}/root/inspection-1').readAsString(),
      )['PjName'],
      'Inspektion v2',
    );
    expect(
      await File('${targetDirectory.path}/documents/report.pdf').readAsBytes(),
      [9, 8, 7],
    );
    expect(
        await File('${targetDirectory.path}/images/photo.jpg').exists(), false);
    expect(await File('${targetDirectory.path}/obsolete/data').exists(), false);
    expect(
      await File('${targetDirectory.path}/failed-requests/pending').exists(),
      false,
    );
    expect(
      await File('${targetDirectory.path}/other/options').readAsString(),
      'keep settings',
    );
    expect(
      await File('${targetDirectory.path}/other/__sync_maps__1').exists(),
      false,
    );
    expect(
      await File('${targetDirectory.path}/flutter_assets/runtime')
          .readAsString(),
      'keep runtime',
    );
    expect(await workingDirectory.list().isEmpty, true);
  });

  test(
      'imports only selected inspections and never queues an existing project again',
      () async {
    await File('${sourceDirectory.path}/old-user/inspection-100')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': 100,
              'StONr': 1,
              'PjName': 'Noch nicht synchronisiert',
              'local_id': 'inspection-100',
              'offline': true,
            })));
    await File('${sourceDirectory.path}/inspection-100/category-100')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': 100,
              'E1': -1,
              'KurzText': 'Lokale Kategorie',
              'local_id': 'category-100',
              'parent_local_id': 'inspection-100',
              'offline': true,
            })));
    await File('${sourceDirectory.path}/100--1-undefined-undefined/photo.jpg')
        .create(recursive: true)
        .then((file) => file.writeAsBytes([1, 2, 3, 4, 5]));
    await File('${sourceDirectory.path}/old-user/inspection-200')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': 200,
              'StONr': 2,
              'PjName': 'Schon synchronisiert',
              'local_id': 'inspection-200',
            })));
    await File('${sourceDirectory.path}/failed-requests/a1')
        .create(recursive: true)
        .then((file) => file.writeAsString(_failedRequest(100)));
    await File('${sourceDirectory.path}/failed-requests/a2')
        .writeAsString(_failedRequest(200));
    await File('${sourceDirectory.path}/other/__sync_maps__100')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'localIdMap': {'category-100': '100-7-undefined-undefined'},
              'imageHashMap': <String, String>{},
            })));
    await File('${sourceDirectory.path}/other/__sync_maps__200')
        .writeAsString(jsonEncode({
      'localIdMap': {'old-200': 'server-200'},
      'imageHashMap': <String, String>{},
    }));

    final backup = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );

    await File('${targetDirectory.path}/current-user/inspection-200')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': 200,
              'StONr': 2,
              'PjName': 'Aktueller Serverstand',
              'local_id': 'inspection-200',
              'offline': false,
            })));
    await File('${targetDirectory.path}/failed-requests/current')
        .create(recursive: true)
        .then((file) => file.writeAsString(_failedRequest(300)));

    final preview = await inspectIncrementalBackupChain(
      [backup.backupFile!],
      currentDataDirectory: targetDirectory,
      currentRootId: 'current-user',
      workingDirectory: workingDirectory,
    );

    expect(preview.containsFailedRequests, isTrue);
    expect(preview.inspections, hasLength(2));
    final pending = preview.inspections.singleWhere(
      (inspection) => inspection.projectNumber == '100',
    );
    final existing = preview.inspections.singleWhere(
      (inspection) => inspection.projectNumber == '200',
    );
    expect(pending.alreadyOnDevice, isFalse);
    expect(pending.failedRequestCount, 1);
    expect(existing.alreadyOnDevice, isTrue);
    expect(existing.failedRequestCount, 1);

    final result = await importInspectionsFromIncrementalBackupChain(
      backupFiles: [backup.backupFile!],
      selectedInspectionIds: {pending.selectionId},
      targetDirectory: targetDirectory,
      targetRootId: 'current-user',
      workingDirectory: workingDirectory,
    );

    expect(result.importedInspectionCount, 1);
    expect(result.importedFailedRequestCount, 1);
    expect(
      jsonDecode(await File(
        '${targetDirectory.path}/current-user/inspection-100',
      ).readAsString())['PjName'],
      'Noch nicht synchronisiert',
    );
    expect(
      await File('${targetDirectory.path}/inspection-100/category-100')
          .exists(),
      isTrue,
    );
    expect(
      await File('${targetDirectory.path}/100--1-undefined-undefined/photo.jpg')
          .readAsBytes(),
      [1, 2, 3, 4, 5],
    );
    expect(
      await File('${targetDirectory.path}/other/__sync_maps__100').exists(),
      isTrue,
    );
    expect(
      await File('${targetDirectory.path}/other/__sync_maps__200').exists(),
      isFalse,
    );
    expect(
      jsonDecode(await File(
        '${targetDirectory.path}/current-user/inspection-200',
      ).readAsString())['PjName'],
      'Aktueller Serverstand',
    );
    final importedRequests = (await Directory(
      '${targetDirectory.path}/failed-requests',
    ).list().toList())
        .whereType<File>()
        .toList();
    expect(importedRequests, hasLength(2));
    final queuedProjects = <String>{};
    for (final request in importedRequests) {
      final decoded = jsonDecode(await request.readAsString()) as Map;
      final requestJson = decoded['json'] as Map;
      final data = jsonDecode(requestJson['data'] as String) as Map;
      queuedProjects.add(data['PjNr'].toString());
      if (data['PjNr'].toString() == '100') {
        expect(decoded.containsKey('user'), isFalse);
        expect(requestJson.containsKey('user'), isFalse);
      }
    }
    expect(queuedProjects, {'100', '300'});
  });

  test('rejects importing a project that became present after preview',
      () async {
    await File('${sourceDirectory.path}/old-user/inspection-400')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': 400,
              'StONr': 4,
              'PjName': 'Backupstand',
              'local_id': 'inspection-400',
            })));
    await File('${sourceDirectory.path}/failed-requests/a4')
        .create(recursive: true)
        .then((file) => file.writeAsString(_failedRequest(400)));
    final backup = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final preview = await inspectIncrementalBackupChain(
      [backup.backupFile!],
      currentDataDirectory: targetDirectory,
      currentRootId: 'current-user',
      workingDirectory: workingDirectory,
    );
    final inspection = preview.inspections.single;

    await File('${targetDirectory.path}/current-user/server-400')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': 400,
              'StONr': 4,
              'PjName': 'Inzwischen synchronisiert',
              'local_id': 'server-400',
            })));

    await expectLater(
      importInspectionsFromIncrementalBackupChain(
        backupFiles: [backup.backupFile!],
        selectedInspectionIds: {inspection.selectionId},
        targetDirectory: targetDirectory,
        targetRootId: 'current-user',
        workingDirectory: workingDirectory,
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.message,
          'message',
          contains('Bereits vorhandene Inspektionen'),
        ),
      ),
    );
    expect(
      await Directory('${targetDirectory.path}/failed-requests').exists(),
      isFalse,
    );
  });

  test('v270 rescue reconstructs only records and photos missing on the server',
      () async {
    const project = 700;
    const backupRootId = 'inspection-700';
    const localCategoryId = '__loc__category-700';
    const localCheckpointId = '__loc__checkpoint-700';
    const localDefectId = '__loc__defect-700';
    const serverRootId = '700';
    const serverCategoryId = '700-2-undefined-undefined';
    const serverCheckpointId = '700-2-3-undefined';
    const syncedPhoto = '700--1-undefined-undefined/2026-08-17_10-00-00.jpg';
    const missingPhoto = '700--1--1--1/2026-08-17_11-00-00.jpg';
    final syncedPhotoBytes = <int>[1, 2, 3, 4, 5, 6];

    await File('${sourceDirectory.path}/old-user/$backupRootId')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': project,
              'StONr': 7,
              'PjName': 'Rettungsprojekt',
              'local_id': backupRootId,
              'offline': true,
            })));
    await File('${sourceDirectory.path}/$backupRootId/700-1')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': project,
              'E1': 1,
              'KurzText': 'Unveränderte Server-Kategorie',
              'local_id': '700-1',
              'parent_local_id': backupRootId,
              'offline': true,
            })));
    await File('${sourceDirectory.path}/$backupRootId/$localCategoryId')
        .writeAsString(jsonEncode({
      'PjNr': project,
      'E1': -1,
      'KurzText': 'Schon angelegte lokale Kategorie',
      'ErDat': '2026-08-17T09:00:00.000',
      'Autor': 'COE',
      'mainhash': syncedPhoto,
      'local_id': localCategoryId,
      'parent_local_id': backupRootId,
      'offline': true,
    }));
    await File('${sourceDirectory.path}/$localCategoryId/$localCheckpointId')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': project,
              'E1': -1,
              'E2': -1,
              'KurzText': 'Lokal nach dem Anlegen geändert',
              'ErDat': '2026-08-17T09:15:00.000',
              'Autor': 'COE',
              'local_id': localCheckpointId,
              'parent_local_id': localCategoryId,
              'offline': true,
            })));
    await File('${sourceDirectory.path}/$localCheckpointId/$localDefectId')
        .create(recursive: true)
        .then((file) => file.writeAsString(jsonEncode({
              'PjNr': project,
              'E1': -1,
              'E2': -1,
              'E3': -1,
              'KurzText': 'Noch fehlender Mangel',
              'mainhash': missingPhoto,
              'local_id': localDefectId,
              'parent_local_id': localCheckpointId,
              'offline': true,
            })));
    await File('${sourceDirectory.path}/$syncedPhoto')
        .create(recursive: true)
        .then((file) => file.writeAsBytes(syncedPhotoBytes));
    await File('${sourceDirectory.path}/$missingPhoto')
        .create(recursive: true)
        .then((file) => file.writeAsBytes([9, 8, 7, 6, 5]));

    final backup = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final preview = await inspectIncrementalBackupChain(
      [backup.backupFile!],
      currentDataDirectory: targetDirectory,
      currentRootId: 'current-user',
      workingDirectory: workingDirectory,
    );
    final inspection = preview.inspections.single;
    expect(preview.containsFailedRequests, isFalse);

    final serverSnapshot = BackupServerInspectionSnapshot(
      selectionId: inspection.selectionId,
      location: {
        'PjNr': project,
        'StONr': 7,
        'PjName': 'Rettungsprojekt',
        'local_id': serverRootId,
      },
      categories: [
        {
          'PjNr': project,
          'E1': 1,
          'KurzText': 'Unveränderte Server-Kategorie',
          'local_id': '700-1',
          'parent_local_id': serverRootId,
        },
        {
          'PjNr': project,
          'E1': 2,
          'KurzText': 'Schon angelegte lokale Kategorie',
          'ErDat': '2026-08-17T09:00:00.000',
          'Autor': 'COE',
          'mainhash': 'server-photo-hash',
          'local_id': serverCategoryId,
          'parent_local_id': serverRootId,
        },
      ],
      checkpoints: [
        {
          'PjNr': project,
          'E1': 2,
          'E2': 3,
          'KurzText': 'Alter Servertext',
          'ErDat': '2026-08-17T09:15:00.000',
          'Autor': 'COE',
          'local_id': serverCheckpointId,
          'parent_local_id': serverCategoryId,
        },
      ],
      defects: const [],
      imageContentHashes: {
        'server-photo-hash': sha256.convert(syncedPhotoBytes).toString(),
      },
    );

    final result = await recoverInspectionsFromIncrementalBackupChain(
      backupFiles: [backup.backupFile!],
      selectedInspectionIds: {inspection.selectionId},
      serverSnapshots: [serverSnapshot],
      targetDirectory: targetDirectory,
      targetRootId: 'current-user',
      workingDirectory: workingDirectory,
    );

    expect(result.reconstructedRequestCount, 3);
    expect(result.alreadySynchronizedRecordCount, 3);
    expect(result.alreadySynchronizedImageCount, 1);
    expect(result.skippedUncertainRecordCount, 0);
    expect(
      await File('${targetDirectory.path}/$syncedPhoto').exists(),
      isFalse,
    );
    expect(
      await File('${targetDirectory.path}/$missingPhoto').readAsBytes(),
      [9, 8, 7, 6, 5],
    );

    final restoredCategory = jsonDecode(await File(
      '${targetDirectory.path}/$serverRootId/$serverCategoryId',
    ).readAsString()) as Map;
    expect(restoredCategory['mainhash'], 'server-photo-hash');
    expect(restoredCategory['parent_local_id'], serverRootId);

    final queued = await Directory('${targetDirectory.path}/failed-requests')
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    final signatures = <String>{};
    for (final file in queued) {
      final request = jsonDecode(await file.readAsString()) as Map;
      signatures.add('${request['route']}:${(request['json'] as Map)['type']}');
    }
    expect(signatures, {
      '/update:checkpoint',
      '/set:defect',
      '/image/set:defect',
    });

    final syncMap = jsonDecode(await File(
      '${targetDirectory.path}/other/__sync_maps__$project',
    ).readAsString()) as Map;
    expect(
      (syncMap['localIdMap'] as Map)[localCategoryId],
      serverCategoryId,
    );
    expect(
      (syncMap['localIdMap'] as Map)[localCheckpointId],
      serverCheckpointId,
    );
    expect(
      (syncMap['imageHashMap'] as Map)[syncedPhoto],
      'server-photo-hash',
    );
  });

  test('rejects an incomplete newest chain without changing current data',
      () async {
    final inspection = await File('${sourceDirectory.path}/inspection')
        .writeAsString('version-1');
    final first = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    await inspection.writeAsString('version-2');
    await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    await inspection.writeAsString('version-3');
    final third = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final current = await File('${targetDirectory.path}/current')
        .writeAsString('untouched');

    await expectLater(
      restoreIncrementalBackupChain(
        backupFiles: [first.backupFile!, third.backupFile!],
        targetDirectory: targetDirectory,
        workingDirectory: workingDirectory,
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.message,
          'message',
          contains('unvollständig'),
        ),
      ),
    );

    expect(await current.readAsString(), 'untouched');
    expect(await workingDirectory.list().isEmpty, true);
  });

  test('rejects changed content whose SHA-256 does not match', () async {
    await File('${sourceDirectory.path}/inspection')
        .writeAsString('expected-content');
    final original = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final tampered = File('${testDirectory.path}/tampered.zip');
    _rewriteArchive(
      source: original.backupFile!,
      destination: tampered,
      replacements: {'inspection': utf8.encode('tampered-content')},
    );
    final current = await File('${targetDirectory.path}/current')
        .writeAsString('untouched');

    await expectLater(
      restoreIncrementalBackupChain(
        backupFiles: [tampered],
        targetDirectory: targetDirectory,
        workingDirectory: workingDirectory,
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.message,
          'message',
          anyOf(contains('Größe'), contains('Prüfsumme')),
        ),
      ),
    );

    expect(await current.readAsString(), 'untouched');
  });

  test('rejects path traversal before writing any restored file', () async {
    final malicious = File('${testDirectory.path}/malicious.zip');
    final content = utf8.encode('outside');
    _writeArchive(malicious, {
      '../outside': content,
      incrementalBackupManifestName: utf8.encode(jsonEncode({
        'version': 1,
        'createdAt': DateTime.utc(2026, 8, 17).toIso8601String(),
        'baseBackup': null,
        'changedFiles': ['../outside'],
        'deletedFiles': <String>[],
        'movedFiles': <String, String>{},
        'snapshot': {
          '../outside': {
            'size': content.length,
            'modifiedAtMs': 1,
            'contentHash': sha256.convert(content).toString(),
          },
        },
        'backupChain': ['backup-1.zip'],
      })),
    });
    final current = await File('${targetDirectory.path}/current')
        .writeAsString('untouched');

    await expectLater(
      restoreIncrementalBackupChain(
        backupFiles: [malicious],
        targetDirectory: targetDirectory,
        workingDirectory: workingDirectory,
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.message,
          'message',
          contains('Unsicherer Dateipfad'),
        ),
      ),
    );

    expect(await current.readAsString(), 'untouched');
    expect(await File('${testDirectory.path}/outside').exists(), false);
  });

  test('applies manifest file moves without requiring duplicate contents',
      () async {
    await File('${sourceDirectory.path}/old/location')
        .create(recursive: true)
        .then((file) => file.writeAsString('same-data'));
    final initial = await createIncrementalBackup(
      sourceDirectory: sourceDirectory,
      backupDirectory: backupDirectory,
    );
    final initialManifest = _readManifest(initial.backupFile!);
    final initialName = (initialManifest['backupChain'] as List).last as String;
    final movedName = 'backup-9999999999999.zip';
    final signature = Map<String, dynamic>.from(
      (initialManifest['snapshot'] as Map)['old/location'] as Map,
    );
    final movedManifest = {
      'version': 1,
      'createdAt': DateTime.utc(2030, 1, 1).toIso8601String(),
      'baseBackup': initialName,
      'changedFiles': <String>[],
      'deletedFiles': <String>[],
      'movedFiles': {'old/location': 'new/location'},
      'snapshot': {'new/location': signature},
      'backupChain': [initialName, movedName],
    };
    final movedBackup = File('${testDirectory.path}/renamed-cloud-copy.zip');
    _writeArchive(movedBackup, {
      incrementalBackupManifestName: utf8.encode(jsonEncode(movedManifest)),
    });

    await restoreIncrementalBackupChain(
      backupFiles: [movedBackup, initial.backupFile!],
      targetDirectory: targetDirectory,
      workingDirectory: workingDirectory,
    );

    expect(await File('${targetDirectory.path}/old/location').exists(), false);
    expect(
      await File('${targetDirectory.path}/new/location').readAsString(),
      'same-data',
    );
  });
}

String _failedRequest(int projectNumber) => jsonEncode({
      'route': '/set',
      'user': {'password': 'must-not-be-backed-up'},
      'json': {
        'type': 'category',
        'user': {'password': 'must-not-be-backed-up'},
        'data': jsonEncode({
          'PjNr': projectNumber,
          'E1': -1,
          'local_id': '__loc__$projectNumber',
        }),
      },
      'multipartFiles': <String>[],
      'returnsBinary': false,
    });

Map<String, dynamic> _readManifest(File backup) {
  final archive = ZipDecoder().decodeBytes(backup.readAsBytesSync());
  final manifest = archive.files.singleWhere(
    (file) => file.name == incrementalBackupManifestName,
  );
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(manifest.content as List<int>)) as Map,
  );
}

void _rewriteArchive({
  required File source,
  required File destination,
  required Map<String, List<int>> replacements,
}) {
  final archive = ZipDecoder().decodeBytes(source.readAsBytesSync());
  final files = <String, List<int>>{};
  for (final entry in archive.files.where((entry) => entry.isFile)) {
    files[entry.name] =
        replacements[entry.name] ?? List<int>.from(entry.content as List<int>);
  }
  _writeArchive(destination, files);
}

void _writeArchive(File destination, Map<String, List<int>> files) {
  final encoder = ZipFileEncoder()..create(destination.path);
  try {
    for (final entry in files.entries) {
      encoder.addArchiveFile(
        ArchiveFile(entry.key, entry.value.length, entry.value),
      );
    }
  } finally {
    encoder.close();
  }
}
