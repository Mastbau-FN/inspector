import 'dart:io';

import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collection reader ignores photos and malformed files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'inspector-localstore-reader-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    await File('${directory.path}/6006358-1-3-1').writeAsString(
      '{"local_id":"6006358-1-3-1","PjNr":6006358}',
    );
    await File('${directory.path}/__loc__record').writeAsString(
      '  \n {"local_id":"__loc__record"}',
    );
    await File('${directory.path}/photo.jpg').writeAsBytes(
      const [0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10],
    );
    await File('${directory.path}/broken').writeAsString('{not json');
    final oversized = await File('${directory.path}/oversized').open(
      mode: FileMode.write,
    );
    await oversized.writeByte(0x7b);
    await oversized.truncate(4 * 1024 * 1024 + 1);
    await oversized.close();

    final documents = await readLocalstoreDocumentDirectory(directory);

    expect(documents.keys, containsAll(['6006358-1-3-1', '__loc__record']));
    expect(documents, hasLength(2));
    expect(await countLocalstoreDocumentDirectory(directory), 2);
  });
}
