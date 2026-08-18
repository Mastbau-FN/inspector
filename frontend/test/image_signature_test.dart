import 'dart:convert';

import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasSupportedImageSignature', () {
    test('accepts common image signatures', () {
      expect(hasSupportedImageSignature([0xff, 0xd8, 0xff, 0xe0]), isTrue);
      expect(
        hasSupportedImageSignature(
          [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a],
        ),
        isTrue,
      );
      expect(hasSupportedImageSignature(ascii.encode('GIF89a')), isTrue);
      expect(
        hasSupportedImageSignature(ascii.encode('RIFF1234WEBP')),
        isTrue,
      );
      expect(
        hasSupportedImageSignature([
          0,
          0,
          0,
          24,
          ...ascii.encode('ftyp'),
          ...ascii.encode('heic'),
        ]),
        isTrue,
      );
    });

    test('rejects JSON and arbitrary binary files', () {
      expect(hasSupportedImageSignature(utf8.encode('{"images":[]}')), isFalse);
      expect(hasSupportedImageSignature([0, 1, 2, 3, 4, 5]), isFalse);
      expect(hasSupportedImageSignature(const []), isFalse);
    });
  });
}
