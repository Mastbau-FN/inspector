import 'dart:io';
import 'dart:typed_data';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/download_progress.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses refreshed inspection metadata including documents', () {
    final current = _inspection(id: 'local-old');
    final refreshed = _inspection(
      id: 'local-old',
      documents: [
        DocumentData(filename: 'Plan.pdf', docupath: '/docs/plan.pdf'),
      ],
    );

    final selected = selectRefreshedInspectionForDownload(
      current,
      [refreshed],
    );

    expect(selected, same(refreshed));
    expect(selected!.dokuspaths, hasLength(1));
    expect(selected.dokuspaths!.single.filename, 'Plan.pdf');
  });

  test('normalizes backend document metadata variants', () {
    final inspection = InspectionLocation.fromJson({
      'PjNr': 123,
      'StONr': 7,
      'local_id': 'inspection',
      'dokusPaths': [
        {
          'Filename': 'Plan.pdf',
          'DocuPath': '/docs/plan.pdf',
        },
      ],
    });

    expect(inspection, isNotNull);
    expect(inspection!.dokuspaths, hasLength(1));
    expect(inspection.dokuspaths!.single.filename, 'Plan.pdf');
    expect(inspection.dokuspaths!.single.docupath, '/docs/plan.pdf');
  });

  test('keeps existing document metadata when refreshed data has none', () {
    final current = _inspection(
      id: 'inspection',
      documents: [
        DocumentData(filename: 'Plan.pdf', docupath: '/docs/plan.pdf'),
      ],
    );
    final refreshed = _inspection(id: 'inspection');

    preserveExistingDocumentsForDownload(current, refreshed);

    expect(refreshed.dokuspaths, hasLength(1));
    expect(refreshed.dokuspaths!.single.docupath, '/docs/plan.pdf');
  });

  test('falls back to project and location number when local ids changed', () {
    final current = _inspection(id: 'old-id');
    final refreshed = _inspection(
      id: 'new-id',
      documents: [
        DocumentData(filename: 'Statik.pdf', docupath: '/docs/statik.pdf'),
      ],
    );

    final selected = selectRefreshedInspectionForDownload(
      current,
      [_inspection(id: 'other-id', pjNr: 999), refreshed],
    );

    expect(selected, same(refreshed));
  });

  test('uses the same canonical document scope as the downloader', () {
    final inspection = _inspection(id: 'server-local-id');

    expect(
      API().local.scopeFor(inspection),
      '123-undefined-undefined-undefined',
    );
  });

  test('continues downloading remaining documents after one document fails',
      () async {
    final inspection = _inspection(
      id: 'inspection',
      documents: [
        DocumentData(filename: 'missing.pdf', docupath: '/docs/missing.pdf'),
        DocumentData(filename: 'plan.pdf', docupath: '/docs/plan.pdf'),
      ],
    );
    final downloaded = <String>[];
    final tempDir = await Directory.systemTemp.createTemp('inspection_docs_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final cachedFile = File('${tempDir.path}/plan.pdf')
      ..writeAsBytesSync([1, 2, 3]);

    final succeeded = await cacheInspectionDocumentsForDownload(
      inspection,
      scope: 'scope',
      readCachedDocument: (_, __) async => throw Exception('not cached'),
      downloadDocument: (path, _, __) async {
        downloaded.add(path);
        return path.endsWith('plan.pdf') ? cachedFile : null;
      },
    );

    expect(succeeded, isFalse);
    expect(downloaded, ['/docs/missing.pdf', '/docs/plan.pdf']);
  });

  test('skips already cached documents', () async {
    final inspection = _inspection(
      id: 'inspection',
      documents: [
        DocumentData(filename: 'plan.pdf', docupath: '/docs/plan.pdf'),
      ],
    );
    final tempDir = await Directory.systemTemp.createTemp('inspection_docs_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final cachedFile = File('${tempDir.path}/plan.pdf')
      ..writeAsBytesSync([1, 2, 3]);

    final succeeded = await cacheInspectionDocumentsForDownload(
      inspection,
      scope: 'scope',
      readCachedDocument: (_, __) async => cachedFile,
      downloadDocument: (_, __, ___) async {
        fail('cached documents must not be downloaded again');
      },
    );

    expect(succeeded, isTrue);
  });

  test('reports visible document download progress', () async {
    final inspection = _inspection(
      id: 'inspection',
      documents: [
        DocumentData(filename: 'plan.pdf', docupath: '/docs/plan.pdf'),
        DocumentData(filename: 'statik.pdf', docupath: '/docs/statik.pdf'),
      ],
    );
    final tempDir = await Directory.systemTemp.createTemp('inspection_docs_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final downloadedFile = File('${tempDir.path}/doc.pdf')
      ..writeAsBytesSync([1, 2, 3]);
    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);

    final succeeded = await cacheInspectionDocumentsForDownload(
      inspection,
      progressSession: session,
      scope: 'scope',
      readCachedDocument: (_, __) async => null,
      downloadDocument: (path, _, __) async {
        final token = session.beginTask(
          '',
          key: '/doc/get|$path',
          step: InspectionDownloadSteps.documents,
        );
        session.endTask(token, success: true);
        return downloadedFile;
      },
    );

    final state = session.notifier.value;
    expect(succeeded, isTrue);
    expect(state.stepIndex, InspectionDownloadSteps.documents);
    expect(state.stepCount, InspectionDownloadSteps.count);
    expect(state.currentLabel, InspectionDownloadSteps.documentLabel(2, 2));
    expect(state.totalTasks, 2);
    expect(state.doneTasks, 2);
  });

  test('reports visible image download progress', () async {
    final inspection = _inspection(id: 'inspection');
    inspection.mainhash = 'main-hash';
    inspection.imagehashes = ['detail-hash'];

    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);

    final image = ImageData(
      Image.memory(Uint8List.fromList([0])),
      id: 'image',
    );
    final downloaded = <String>[];

    final succeeded = await cacheInspectionImagesForDownload(
      [inspection],
      progressSession: session,
      readCachedImage: (hash, _) async => hash == 'main-hash' ? image : null,
      downloadImage: (hash, _) async {
        downloaded.add(hash);
        return image;
      },
    );

    final state = session.notifier.value;
    expect(succeeded, isTrue);
    expect(downloaded, ['detail-hash']);
    expect(state.stepIndex, InspectionDownloadSteps.photos);
    expect(state.totalTasks, 2);
    expect(state.doneTasks, 2);
    expect(state.percent, 100);
  });

  test('reports document phase even when inspection has no documents',
      () async {
    final inspection = _inspection(id: 'inspection', documents: []);
    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);

    final succeeded = await cacheInspectionDocumentsForDownload(
      inspection,
      progressSession: session,
      scope: 'scope',
    );

    final state = session.notifier.value;
    expect(succeeded, isTrue);
    expect(state.stepIndex, InspectionDownloadSteps.documents);
    expect(state.currentLabel, InspectionDownloadSteps.noDocumentsLabel);
  });

  test('download progress does not jump back to earlier steps', () {
    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);

    session.setStep(
      InspectionDownloadSteps.defects,
      label: InspectionDownloadSteps.defectsLabel,
    );
    session.setStep(
      InspectionDownloadSteps.checkpoints,
      label: InspectionDownloadSteps.checkpointsLabel,
    );

    final state = session.notifier.value;
    expect(state.stepIndex, InspectionDownloadSteps.defects);
    expect(state.currentLabel, InspectionDownloadSteps.defectsLabel);
  });

  test('download progress reaches 100 percent when step tasks are done', () {
    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);

    session.setStep(
      InspectionDownloadSteps.defects,
      label: InspectionDownloadSteps.defectsLabel,
    );
    final tokens = List.generate(
      99,
      (index) => session.beginTask(
        '',
        key: 'defect-$index',
        step: InspectionDownloadSteps.defects,
      ),
    );
    for (final token in tokens) {
      session.endTask(token, success: true);
    }

    expect(session.notifier.value.doneTasks, 99);
    expect(session.notifier.value.totalTasks, 99);
    expect(session.notifier.value.percent, 100);
  });

  test('inspection download queue runs tasks one after another', () async {
    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);

    var activeTasks = 0;
    var maxActiveTasks = 0;
    final order = <String>[];

    Future<String> queuedTask(String name) {
      return session.enqueueDownload(() async {
        activeTasks++;
        if (activeTasks > maxActiveTasks) maxActiveTasks = activeTasks;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        order.add(name);
        activeTasks--;
        return name;
      });
    }

    final results = await Future.wait([
      queuedTask('first'),
      queuedTask('second'),
      queuedTask('third'),
    ]);

    expect(results, ['first', 'second', 'third']);
    expect(order, ['first', 'second', 'third']);
    expect(maxActiveTasks, 1);
  });

  test('inspection download queue continues after a failed task', () async {
    final session = DownloadProgressSession(
      stepCount: InspectionDownloadSteps.count,
    );
    addTearDown(session.dispose);
    final order = <String>[];

    final failing = session.enqueueDownload<void>(() async {
      order.add('first');
      throw StateError('failed');
    });
    final succeeding = session.enqueueDownload(() async {
      order.add('second');
      return true;
    });

    await expectLater(failing, throwsStateError);
    expect(await succeeding, isTrue);
    expect(order, ['first', 'second']);
  });

  test('active download session can be recovered by inspection key', () {
    const key = 'inspection:123:7';
    final progress = DownloadProgress.instance;
    final session = progress.start(
      key: key,
      stepCount: InspectionDownloadSteps.count,
    );

    expect(progress.activeFor(key), same(session));
    expect(
      progress.start(
        key: key,
        stepCount: InspectionDownloadSteps.count,
      ),
      same(session),
    );

    progress.finish(session);
    expect(progress.activeFor(key), isNull);
  });
}

InspectionLocation _inspection({
  required String id,
  int pjNr = 123,
  List<DocumentData>? documents,
}) {
  final inspection = InspectionLocation(
    pjNr: pjNr,
    stONr: 7,
    dokuspaths: documents,
  );
  inspection.id = id;
  return inspection;
}
