import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart'
    show
        CameraPlatform,
        CameraInitializedEvent,
        DeviceOrientationChangedEvent,
        MediaSettings;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Replace camera hardware only; shoot(), file handling and Flutter's decoder
// are real, so the assertions cover the bytes used by preview/save/upload.
class _CameraHardware extends CameraPlatform {
  _CameraHardware(this.lens, this.capture);
  final CameraLensDirection lens;
  final File capture;

  @override
  Future<List<CameraDescription>> availableCameras() async => [
        CameraDescription(
            name: 'fixture', lensDirection: lens, sensorOrientation: 90),
      ];
  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();
  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription,
          MediaSettings mediaSettings) async =>
      7;
  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(cameraId, 1920, 1080, ExposureMode.auto, true,
            FocusMode.auto, true),
      );
  @override
  Future<void> initializeCamera(int cameraId,
      {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}
  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;
  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 4;
  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}
  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}
  @override
  Future<XFile> takePicture(int cameraId) async => XFile(capture.path);
  @override
  Future<void> dispose(int cameraId) async {}
}

class _ReleaseHardware extends _CameraHardware {
  _ReleaseHardware(super.lens, super.capture);
  final released = Completer<void>();
  final finishRelease = Completer<void>();

  @override
  Future<void> dispose(int cameraId) async {
    if (!released.isCompleted) released.complete();
    await finishRelease.future;
  }
}

class _TakingHardware extends _CameraHardware {
  _TakingHardware(super.lens, super.capture);
  final started = Completer<void>();
  final finishPicture = Completer<XFile>();

  @override
  Future<XFile> takePicture(int cameraId) {
    started.complete();
    return finishPicture.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  late CameraPlatform originalPlatform;
  const red = [255, 0, 0];
  const green = [0, 255, 0];
  const blue = [0, 0, 255];
  const yellow = [255, 255, 0];

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('inspector-camera-mirror-');
    originalPlatform = CameraPlatform.instance;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => cache.path,
    );
  });
  tearDown(() async {
    CameraPlatform.instance = originalPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await cache.delete(recursive: true);
  });

  Future<File> fixture(int orientation) async {
    final image = img.Image(width: 64, height: 32);
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 64; x++) {
        final color =
            y < 16 ? (x < 32 ? red : green) : (x < 32 ? blue : yellow);
        image.setPixelRgb(x, y, color[0], color[1], color[2]);
      }
    }
    image.exif.imageIfd.orientation = orientation;
    return File('${cache.path}/CAP-fixture.jpg')
      ..writeAsBytesSync(img.encodeJpg(image, quality: 100));
  }

  Future<void> expectCorners(
      XFile photo, List<List<int>> expected, int width, int height) async {
    final codec = await ui.instantiateImageCodec(await photo.readAsBytes());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    expect(image.width, width);
    expect(image.height, height);
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final points = [
      (4, 4),
      (width - 5, 4),
      (4, height - 5),
      (width - 5, height - 5)
    ];
    for (var i = 0; i < points.length; i++) {
      final (x, y) = points[i];
      for (var c = 0; c < 3; c++) {
        expect(
            rgba.getUint8((y * width + x) * 4 + c), closeTo(expected[i][c], 15),
            reason: 'corner $i, channel $c');
      }
    }
    image.dispose();
    codec.dispose();
  }

  // Hand-derived corners after EXIF orientation, then horizontal mirroring.
  final expected = [
    [green, red, yellow, blue],
    [red, green, blue, yellow],
    [blue, yellow, red, green],
    [yellow, blue, green, red],
    [blue, red, yellow, green],
    [red, blue, green, yellow],
    [green, yellow, red, blue],
    [yellow, green, blue, red],
  ];
  for (var orientation = 1; orientation <= 8; orientation++) {
    test('selfie file matches mirrored preview for EXIF $orientation',
        () async {
      final file = await fixture(orientation);
      CameraPlatform.instance =
          _CameraHardware(CameraLensDirection.front, file);
      final model = CameraModel();
      try {
        final photo = await model.shoot();
        expect(model.latestPic?.path, photo.path);
        await expectCorners(photo, expected[orientation - 1],
            orientation < 5 ? 64 : 32, orientation < 5 ? 32 : 64);
      } finally {
        model.discardPic(deleteTemporaryFile: false);
        model.dispose();
      }
    });
  }

  test('rear camera keeps original JPEG bytes and metadata', () async {
    final file = await fixture(6);
    final original = await file.readAsBytes();
    CameraPlatform.instance = _CameraHardware(CameraLensDirection.back, file);
    final model = CameraModel();
    try {
      final photo = await model.shoot();
      expect(await photo.readAsBytes(), original);
    } finally {
      model.discardPic(deleteTemporaryFile: false);
      model.dispose();
    }
  });

  test('invalid selfie cannot be shown or saved as a successful capture',
      () async {
    final file = File('${cache.path}/CAP-invalid.jpg')
      ..writeAsBytesSync([1, 2, 3]);
    CameraPlatform.instance = _CameraHardware(CameraLensDirection.front, file);
    final model = CameraModel();
    try {
      await expectLater(model.shoot(), throwsException);
      expect(model.latestPic, isNull);
      expect(model.isProcessing, isFalse);
    } finally {
      model.discardPic(deleteTemporaryFile: false);
      model.dispose();
    }
  });

  for (final action in ['dispose', 'discard', 'close', 'queue']) {
    test('$action during capture cannot publish a late selfie', () async {
      final file = await fixture(6);
      final hardware = _ReleaseHardware(CameraLensDirection.front, file);
      CameraPlatform.instance = hardware;
      final model = CameraModel();
      final replacement = File('${cache.path}/queued.jpg')
        ..writeAsBytesSync([8, 9, 10]);
      final result = model
          .shoot()
          .then<Object?>((_) => null, onError: (Object error) => error);
      await hardware.released.future;
      if (action == 'dispose') {
        model.dispose();
      } else if (action == 'discard') {
        model.discardPic();
      } else if (action == 'close') {
        await model.disposeCamera();
      } else {
        model.latestPic = XFile(replacement.path);
      }
      hardware.finishRelease.complete();
      try {
        expect(await result, isA<Exception>());
        expect(model.latestPic?.path,
            action == 'queue' ? replacement.path : isNull);
        expect(await file.exists(), isFalse);
        expect(await replacement.readAsBytes(), [8, 9, 10]);
      } finally {
        if (action != 'dispose') {
          model.discardPic(deleteTemporaryFile: false);
          model.dispose();
        }
      }
    });
  }

  test('focus, zoom and flash are ignored during capture processing', () async {
    final file = await fixture(6);
    final hardware = _ReleaseHardware(CameraLensDirection.front, file);
    CameraPlatform.instance = hardware;
    final model = CameraModel();
    final result = model.shoot();
    await hardware.released.future;
    try {
      await model.setZoom(2);
      await model.focus(const Offset(.25, .25));
      await model.setFlashMode(FlashMode.auto);
      expect(model.flashMode, FlashMode.off);
      expect(model.controller, isNull);
    } finally {
      hardware.finishRelease.complete();
      await result;
      model.discardPic(deleteTemporaryFile: false);
      model.dispose();
    }
  });

  for (final action in ['close', 'dispose']) {
    test('$action before native capture completes cleans the eventual JPEG',
        () async {
      final file = await fixture(6);
      final hardware = _TakingHardware(CameraLensDirection.front, file);
      CameraPlatform.instance = hardware;
      final model = CameraModel();
      final result = model
          .shoot()
          .then<Object?>((_) => null, onError: (Object error) => error);
      await hardware.started.future;
      Future<void>? closing;
      if (action == 'dispose') {
        model.dispose();
      } else {
        closing = model.disposeCamera();
      }
      // Allow an eager native disposal to complete before the JPEG is ready.
      await Future<void>.delayed(Duration.zero);
      hardware.finishPicture.complete(XFile(file.path));
      try {
        await closing;
        expect(await result, isA<CameraCaptureCancelled>());
        expect(model.latestPic, isNull);
        expect(await file.exists(), isFalse);
      } finally {
        if (action != 'dispose') model.dispose();
      }
    });
  }
}
