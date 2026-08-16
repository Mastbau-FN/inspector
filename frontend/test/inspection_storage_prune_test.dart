import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory testDirectory;

  setUp(() async {
    testDirectory =
        await Directory.systemTemp.createTemp('mbg-inspection-prune-');
  });

  tearDown(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('removes all storage for server-absent inspections', () async {
    const activePjNr = '6000100';
    const inactivePjNr = '6000200';
    const offlinePjNr = '6000300';

    final root = await Directory('${testDirectory.path}/NL').create();
    final activeRoot = await _writeJson(
      '${root.path}/$activePjNr-undefined-undefined-undefined',
      {'PjNr': int.parse(activePjNr)},
    );
    final inactiveRoot = await _writeJson(
      '${root.path}/$inactivePjNr-undefined-undefined-undefined',
      {'PjNr': int.parse(inactivePjNr)},
    );
    final offlineRoot = await _writeJson(
      '${root.path}/$offlinePjNr-undefined-undefined-undefined',
      {'PjNr': int.parse(offlinePjNr), 'offline': true},
    );

    final activeImage = await File(
      '${testDirectory.path}/$activePjNr-1-2-3/active.jpg',
    ).create(recursive: true);
    final inactiveImage = await File(
      '${testDirectory.path}/$inactivePjNr-1-2-3/inactive.jpg',
    ).create(recursive: true);
    final offlineImage = await File(
      '${testDirectory.path}/$offlinePjNr-1-2-3/offline.jpg',
    ).create(recursive: true);

    final localCollection =
        await Directory('${testDirectory.path}/__loc__parent').create();
    final inactiveLocalChild = await _writeJson(
      '${localCollection.path}/__loc__child',
      {'PjNr': int.parse(inactivePjNr)},
    );

    final mixedCollection =
        await Directory('${testDirectory.path}/mixed-parent').create();
    final activeChild = await _writeJson(
      '${mixedCollection.path}/active-child',
      {'PjNr': int.parse(activePjNr)},
    );
    final inactiveChild = await _writeJson(
      '${mixedCollection.path}/inactive-child',
      {'PjNr': int.parse(inactivePjNr)},
    );

    final failedDirectory =
        await Directory('${testDirectory.path}/failed-requests').create();
    final inactiveFailed = await _writeJson(
      '${failedDirectory.path}/request-inactive',
      {
        'json': {
          'data': jsonEncode({'PjNr': int.parse(inactivePjNr)}),
        },
      },
    );
    final activeFailed = await _writeJson(
      '${failedDirectory.path}/request-active',
      {
        'json': {
          'data': jsonEncode({'PjNr': int.parse(activePjNr)}),
        },
      },
    );

    final skippedDirectory =
        await Directory('${testDirectory.path}/skipped-requests').create();
    final inactiveSkipped = await _writeJson(
      '${skippedDirectory.path}/request-inactive',
      {'PjNr': int.parse(inactivePjNr)},
    );

    final imageIndex =
        await Directory('${testDirectory.path}/image-index').create();
    final inactiveIndex = await _writeJson(
      '${imageIndex.path}/inactive-index',
      {'scope': '$inactivePjNr-1-2-3', 'storedName': 'photo.jpg'},
    );
    final activeIndex = await _writeJson(
      '${imageIndex.path}/active-index',
      {'scope': '$activePjNr-1-2-3', 'storedName': 'photo.jpg'},
    );

    final other = await Directory('${testDirectory.path}/other').create();
    final inactiveSyncMap = await _writeJson(
      '${other.path}/__sync_maps__$inactivePjNr',
      {'localIdMap': {}},
    );
    final activeSyncMap = await _writeJson(
      '${other.path}/__sync_maps__$activePjNr',
      {'localIdMap': {}},
    );
    final settings = await _writeJson(
      '${other.path}/options',
      {'lastProject': inactivePjNr},
    );

    final runtimeAsset = await _writeJson(
      '${testDirectory.path}/flutter_assets/$inactivePjNr-runtime.json',
      {'PjNr': int.parse(inactivePjNr)},
    );

    final removed = await pruneInactiveInspectionStorageAt(
      applicationDocumentsDirectory: testDirectory,
      retainedPjNrs: {activePjNr, offlinePjNr},
    );

    expect(removed, contains(inactivePjNr));
    expect(await inactiveRoot.exists(), isFalse);
    expect(await inactiveImage.parent.exists(), isFalse);
    expect(await inactiveLocalChild.exists(), isFalse);
    expect(await localCollection.exists(), isFalse);
    expect(await inactiveChild.exists(), isFalse);
    expect(await inactiveFailed.exists(), isFalse);
    expect(await inactiveSkipped.exists(), isFalse);
    expect(await inactiveIndex.exists(), isFalse);
    expect(await inactiveSyncMap.exists(), isFalse);

    expect(await activeRoot.exists(), isTrue);
    expect(await offlineRoot.exists(), isTrue);
    expect(await activeImage.exists(), isTrue);
    expect(await offlineImage.exists(), isTrue);
    expect(await activeChild.exists(), isTrue);
    expect(await activeFailed.exists(), isTrue);
    expect(await activeIndex.exists(), isTrue);
    expect(await activeSyncMap.exists(), isTrue);
    expect(await settings.exists(), isTrue);
    expect(await runtimeAsset.exists(), isTrue);
  });
}

Future<File> _writeJson(String path, Map<String, dynamic> value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  return file.writeAsString(jsonEncode(value));
}
