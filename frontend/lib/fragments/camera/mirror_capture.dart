import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Mirror the actual saved selfie, so every consumer uses the same image.
/// Camera buffers must be released before decoding the full-resolution JPEG.
Future<XFile> mirrorSelfieCapture(XFile capture) async {
  await compute(_mirrorJpeg, capture.path);
  return capture;
}

void _mirrorJpeg(String path) {
  final source = File(path);
  // decodeJpg already bakes all EXIF rotations/reflections into the pixels.
  final image = img.decodeJpg(source.readAsBytesSync());
  if (image == null) throw const FormatException('Ungültige Kameraaufnahme');
  img.flipHorizontal(image);
  image.exif.imageIfd.orientation = 1;
  // An embedded thumbnail would still show the unmirrored original.
  image.exif.directories.remove('ifd1');

  final temporary = File('$path.mbg-mirror');
  try {
    temporary.writeAsBytesSync(img.encodeJpg(image, quality: 95), flush: true);
    temporary.renameSync(path);
  } finally {
    if (temporary.existsSync()) temporary.deleteSync();
  }
}
