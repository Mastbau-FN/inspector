import 'dart:math';

import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rotates front camera portrait preview upright for 270 degree sensors',
      () {
    final frontCamera = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

    expect(
      cameraPreviewRotationAngle(
        camera: frontCamera,
        orientation: Orientation.portrait,
      ),
      closeTo(-pi / 2, 0.0001),
    );
  });

  test('keeps existing back camera portrait rotation', () {
    final backCamera = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );

    expect(
      cameraPreviewRotationAngle(
        camera: backCamera,
        orientation: Orientation.portrait,
      ),
      closeTo(pi / 2, 0.0001),
    );
  });

  test('keeps existing landscape preview rotation', () {
    final frontCamera = CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    );

    expect(
      cameraPreviewRotationAngle(
        camera: frontCamera,
        orientation: Orientation.landscape,
      ),
      closeTo(pi / 2, 0.0001),
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
