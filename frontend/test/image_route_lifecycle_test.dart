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
}
