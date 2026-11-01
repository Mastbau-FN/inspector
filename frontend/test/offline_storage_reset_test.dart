import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' as offline;
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localstore/src/utils/io.dart' as localstore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporary;
  late Directory documents;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('inspector-reset-');
    documents = await Directory('${temporary.path}/documents').create();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documents.path;
      }
      if (call.method == 'getApplicationCacheDirectory' ||
          call.method == 'getTemporaryDirectory') {
        return '${temporary.path}/cache';
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test('an awaited cache write propagates a filesystem failure', () async {
    await File('${documents.path}/blocked').writeAsString('not a directory');
    final inspection = InspectionLocation(pjNr: 6006387, stONr: 31592)
      ..id = 'blocked-inspection';

    await IOOverrides.runZoned(() async {
      await expectLater(
        offline.storeData(inspection, forId: 'blocked'),
        throwsA(isA<FileSystemException>()),
      );
    }, getCurrentDirectory: () => documents);
  });

  test('downloaded inspection and defect photos remain readable after reset',
      () async {
    await IOOverrides.runZoned(() async {
      final inspection = InspectionLocation(pjNr: 6006386, stONr: 31592)
        ..id = '6006386-undefined-undefined-undefined'
        ..mainhash = 'inspection-photo'
        ..forceOffline = true;
      final defect = CheckPointDefect(
        pjNr: 6006386,
        category_index: 14,
        check_index: 1,
        index: 1,
      )
        ..id = '6006386-14-1-1'
        ..mainhash = 'defect-photo'
        ..forceOffline = true;
      final rootDoc = offline.db.collection('reset-user').doc(inspection.id);
      final defectDoc = offline.db.collection('6006386-14-1-0').doc(defect.id);

      // Prime the real storage library's cached File handles, then model the
      // developer reset without starting a new process.
      await localstore.Utils.instance.set(inspection.toJson(), rootDoc.path);
      await localstore.Utils.instance.set(defect.toJson(), defectDoc.path);
      await documents.delete(recursive: true);

      await offline.storeData(inspection, forId: 'reset-user');
      await offline.storeData(defect, forId: '6006386-14-1-0');
      final png = Uint8List.fromList(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jY1sAAAAASUVORK5CYII=',
      ));
      for (final owner in [inspection, defect]) {
        final scope = LocalMirror().scopeFor(owner);
        final storedName = '$scope/photo.png';
        await offline.storeImage(png, storedName);
        await offline.indexImageHash(
          hash: owner.mainhash!,
          storedName: storedName,
          scope: scope,
        );
      }

      final rootFile = File('${documents.path}/reset-user/${inspection.id}');
      final defectFile = File('${documents.path}/6006386-14-1-0/${defect.id}');
      expect(jsonDecode(await rootFile.readAsString())['offline'], isTrue);
      expect(jsonDecode(await defectFile.readAsString())['offline'], isTrue);
      final roots =
          await offline.getAllChildrenFrom<InspectionLocation>('reset-user');
      final defects =
          await offline.getAllChildrenFrom<CheckPointDefect>('6006386-14-1-0');
      for (final owner in [roots!.single!, defects!.single!]) {
        final image =
            await LocalMirror().getImageByHash(owner.mainhash!, owner: owner);
        expect(image, isNotNull);
      }
      final indexFiles = await Directory('${documents.path}/image-index')
          .list()
          .where((entry) => entry is File)
          .toList();
      expect(indexFiles, hasLength(4));
      for (final file in indexFiles) {
        expect(jsonDecode(await File(file.path).readAsString())['storedName'],
            endsWith('/photo.png'));
      }
    }, getCurrentDirectory: () => documents);
  });

  test('reset completes before its future reports success', () async {
    await File('${documents.path}/inspection/photo.jpg')
        .create(recursive: true);
    await offline.deleteAll();
    expect(await documents.exists(), isFalse);
  });
}
