import 'dart:math';

import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('corrects the front camera sensor rotation in portrait', () {
    final frontCamera = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

    expect(
      cameraPreviewRotationAngle(
        camera: frontCamera,
        orientation: Orientation.portrait,
        androidSdkInt: 35,
      ),
      closeTo(3 * pi / 2, 0.0001),
    );
  });

  test('corrects the back camera sensor rotation in portrait', () {
    final backCamera = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );

    expect(
      cameraPreviewRotationAngle(
        camera: backCamera,
        orientation: Orientation.portrait,
        androidSdkInt: 35,
      ),
      closeTo(pi / 2, 0.0001),
    );
  });

  test('reverses front sensor correction in landscape', () {
    final frontCamera = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

    expect(
      cameraPreviewRotationAngle(
        camera: frontCamera,
        orientation: Orientation.landscape,
        androidSdkInt: 35,
      ),
      closeTo(-3 * pi / 2, 0.0001),
    );
  });

  test('mirrors front camera preview horizontally', () {
    final frontCamera = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

    expect(cameraPreviewScaleX(frontCamera), -1);
  });

  test('does not mirror back camera preview', () {
    final backCamera = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );

    expect(cameraPreviewScaleX(backCamera), 1);
  });
}
