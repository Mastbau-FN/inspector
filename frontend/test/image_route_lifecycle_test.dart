import 'dart:typed_data';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/galleryWrapper.dart';
import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offstage photo grids do not request decoded images',
      (tester) async {
    var fullImageCalls = 0;
    final imageData = ImageData<String>(
      Image.memory(Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xd9])),
      id: 'photo',
    );
    imageData.fullImageGetter = () async {
      fullImageCalls++;
      return imageData.image;
    };
    final item = ImageItem<String>.fromImageData(imageData);
    addTearDown(item.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TickerMode(
          enabled: false,
          child: FittedImageContainer(
            item: item,
            approxWidth: 100,
          ),
        ),
      ),
    );

    expect(fullImageCalls, 0);
  });

  test('gallery hides transient local/hash aliases of the same photo', () {
    final bytes = Uint8List.fromList(const [0xff, 0xd8, 0xff, 0xd9]);
    final local = ImageItem<String>.fromImageData(
      ImageData<String>(
        Image.memory(bytes),
        id: 'scope/24_08_2026_14_00_00.jpg',
        name: '24_08_2026_14_00_00',
      ),
    );
    final backend = ImageItem<String>.fromImageData(
      ImageData<String>(
        Image.memory(bytes),
        id: 'backend-hash',
        name: '24_08_2026_14_00_00',
      ),
    );
    final other = ImageItem<String>.fromImageData(
      ImageData<String>(
        Image.memory(bytes),
        id: 'other-hash',
        name: '24_08_2026_14_00_01',
      ),
    );
    addTearDown(() {
      local.dispose();
      backend.dispose();
      other.dispose();
    });

    expect(uniqueVisibleImageItems([local, backend, other]), [local, other]);
  });
}
