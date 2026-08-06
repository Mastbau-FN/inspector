import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/backend/remote.dart';
import 'package:MBG_Inspektionen/classes/exceptions.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter_test/flutter_test.dart';

RequestData request(
  String route, {
  String? type,
  Map<String, dynamic>? data,
}) {
  return RequestData(
    route,
    json: {
      if (type != null) 'type': type,
      if (data != null) 'data': jsonEncode(data),
    },
  );
}

void main() {
  test('creation requests are ordered before dependent image uploads', () {
    final requests = <(String, RequestData?)>[
      ('1', request('/image/set', type: 'defect')),
      ('2', request('/set', type: 'defect')),
      ('3', request('/set', type: 'category')),
      ('4', request('/set', type: 'checkpoint')),
      ('5', request('/update', type: 'defect')),
      ('6', request('/setMainImgH', type: 'defect')),
    ];

    final sorted = sortSyncRequestsForDependencies(requests);

    expect(
      sorted.map((entry) => '${entry.$2!.route}:${entry.$2!.json?['type']}'),
      [
        '/set:category',
        '/set:checkpoint',
        '/set:defect',
        '/update:defect',
        '/image/set:defect',
        '/setMainImgH:defect',
      ],
    );
  });

  test('request order remains chronological within one dependency level', () {
    final sorted = sortSyncRequestsForDependencies([
      ('b', request('/image/set', type: 'defect')),
      ('9', request('/image/set', type: 'defect')),
      ('a', request('/image/set', type: 'defect')),
    ]);

    expect(sorted.map((entry) => entry.$1), ['9', 'a', 'b']);
  });

  test('image recovery searches unresolved child and numeric parent scopes',
      () {
    const filename = '31_07_2026_08_38_04.jpg';
    final upload = request(
      '/image/set',
      type: 'defect',
      data: {
        'PjNr': 20266472,
        'E1': 5,
        'E2': 1,
        'E3': -1,
        'local_id': '__loc__1tpm10',
        'parent_local_id': '20266472-5-1-0',
        'mainhash': '20266472-5-1--1/$filename',
        'images': <String>[],
      },
    );

    final candidates = multipartFileCandidates(upload, filename);

    expect(candidates, contains('20266472-5-1--1/$filename'));
    expect(candidates, contains('20266472-5-1-0/$filename'));
    expect(candidates, contains(filename));
    expect(imageUploadNeedsServerId(upload), isTrue);

    final mappedUpload = request(
      '/image/set',
      type: 'defect',
      data: {
        'PjNr': 20266472,
        'E1': 5,
        'E2': 1,
        'E3': -1,
        'local_id': '20266472-5-1-42',
      },
    );
    expect(imageUploadNeedsServerId(mappedUpload), isFalse);
  });

  test('failed upload persistence keeps the unresolved child scope', () {
    const filename = '31_07_2026_08_38_04.jpg';
    final json = {
      'type': 'defect',
      'data': jsonEncode({
        'PjNr': 20266472,
        'E1': 5,
        'E2': 1,
        'E3': -1,
        'parent_local_id': '20266472-5-1-0',
        'mainhash': '20266472-5-1--1/$filename',
      }),
    };

    expect(deriveRequestStorageScope(json), '20266472-5-1--1');
  });

  test('missing and truncated multipart files fail before network sending', () {
    final directory = Directory.systemTemp.createTempSync('sync-upload-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final missing = '${directory.path}/missing.jpg';
    final truncated = File('${directory.path}/truncated.jpg')
      ..writeAsBytesSync([1, 2, 3]);

    expect(
      () => validateMultipartFileForUpload(missing),
      throwsA(isA<MultipartFileUnavailableException>()),
    );
    expect(
      () => validateMultipartFileForUpload(truncated.path),
      throwsA(isA<MultipartFileUnavailableException>()),
    );
  });

  test('valid multipart files pass local preflight validation', () {
    final directory = Directory.systemTemp.createTempSync('sync-upload-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final image = File('${directory.path}/image.jpg')
      ..writeAsBytesSync([1, 2, 3, 4, 5]);

    expect(validateMultipartFileForUpload(image.path).size, 5);
  });
}
