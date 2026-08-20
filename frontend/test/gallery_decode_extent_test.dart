import 'package:MBG_Inspektionen/fragments/galleryWrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active gallery image gets zoom detail without large neighbours', () {
    const mediaQuery = MediaQueryData(
      size: Size(412, 915),
      devicePixelRatio: 3,
    );

    final current = galleryDecodeExtent(mediaQuery, isCurrent: true);
    final neighbour = galleryDecodeExtent(mediaQuery, isCurrent: false);

    expect(current, 4096);
    expect(neighbour, 1647);
    expect(current, greaterThan(neighbour * 2));
  });

  test('gallery decode extents remain bounded on unusual displays', () {
    const small = MediaQueryData(
      size: Size(240, 320),
      devicePixelRatio: 1,
    );
    const large = MediaQueryData(
      size: Size(1440, 3200),
      devicePixelRatio: 4,
    );

    expect(galleryDecodeExtent(small, isCurrent: true), 2048);
    expect(galleryDecodeExtent(small, isCurrent: false), 768);
    expect(galleryDecodeExtent(large, isCurrent: true), 4096);
    expect(galleryDecodeExtent(large, isCurrent: false), 1920);
  });
}
