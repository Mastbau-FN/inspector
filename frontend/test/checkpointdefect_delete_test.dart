import 'dart:io';

import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleting a defect scope removes only its cached images', () async {
    final root = await Directory.systemTemp.createTemp('defect-delete-test-');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    const deletedScope = '123-4-9-1';
    const neighboringScope = '123-4-9-2';
    final deletedDirectory = Directory('${root.path}/$deletedScope')
      ..createSync(recursive: true);
    final neighboringDirectory = Directory('${root.path}/$neighboringScope')
      ..createSync(recursive: true);
    final oldImage = File('${deletedDirectory.path}/old.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    final unrelatedFile = File('${deletedDirectory.path}/note.txt')
      ..writeAsStringSync('keep');
    final neighboringImage = File('${neighboringDirectory.path}/other.jpg')
      ..writeAsBytesSync([4, 5, 6]);

    await deleteScopedImageFilesAt(deletedScope, root.path);

    expect(oldImage.existsSync(), isFalse);
    expect(unrelatedFile.existsSync(), isTrue);
    expect(neighboringImage.existsSync(), isTrue);
  });
}
