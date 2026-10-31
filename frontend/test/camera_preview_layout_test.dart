import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Only the native texture and camera startup are replaced. Layout, controller
// orientation handling, mirroring and the application's preview stay real.
class _TextureController extends CameraController {
  _TextureController(CameraDescription camera, DeviceOrientation orientation)
      : super(camera, ResolutionPreset.ultraHigh) {
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
      deviceOrientation: orientation,
    );
  }

  @override
  Widget buildPreview() => const SizedBox.expand(
        key: ValueKey('sensor-texture'),
        child: Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(
                key: ValueKey('sensor-top-left'), width: 10, height: 10),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
                key: ValueKey('sensor-top-right'), width: 10, height: 10),
          ),
        ]),
      );
}

class _PreviewModel extends CameraModel {
  _PreviewModel(this.previewController, {this.androidSdkInt = 35});
  final CameraController previewController;
  @override
  final int androidSdkInt;

  @override
  Future<CameraController> start({bool reuse = true}) async =>
      previewController;
}

class _BusyPreviewModel extends _PreviewModel {
  _BusyPreviewModel(super.previewController);
  @override
  bool get isProcessing => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('volume_button_events'), (_) async => null);
  });

  testWidgets(
      'released camera stays on loading screen during capture processing',
      (tester) async {
    final controller = _TextureController(
      const CameraDescription(
          name: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270),
      DeviceOrientation.portraitUp,
    );
    final model = _BusyPreviewModel(controller);
    await tester.pumpWidget(ChangeNotifierProvider<CameraModel>.value(
      value: model,
      child: const MaterialApp(home: Scaffold(body: CameraPreviewOnly())),
    ));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.byType(CameraInteractionHandler), findsNothing);
    await tester.pumpWidget(const SizedBox());
    model.dispose();
    await controller.dispose();
  });

  final cases = [
    (
      CameraLensDirection.back,
      90,
      DeviceOrientation.portraitUp,
      'top-right',
      'bottom-right'
    ),
    (
      CameraLensDirection.front,
      270,
      DeviceOrientation.portraitUp,
      'bottom-right',
      'top-right'
    ),
    (
      CameraLensDirection.back,
      90,
      DeviceOrientation.landscapeLeft,
      'top-left',
      'top-right'
    ),
    (
      CameraLensDirection.front,
      270,
      DeviceOrientation.landscapeLeft,
      'top-right',
      'top-left'
    ),
    (
      CameraLensDirection.back,
      90,
      DeviceOrientation.landscapeRight,
      'bottom-right',
      'bottom-left'
    ),
    (
      CameraLensDirection.front,
      270,
      DeviceOrientation.landscapeRight,
      'bottom-left',
      'bottom-right'
    ),
  ];

  for (final (lens, sensor, orientation, topLeft, topRight) in cases) {
    testWidgets('$lens $orientation fits the full upright sensor image',
        (tester) async {
      final landscape = orientation == DeviceOrientation.landscapeLeft ||
          orientation == DeviceOrientation.landscapeRight;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize =
          landscape ? const Size(1000, 600) : const Size(600, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _TextureController(
        CameraDescription(
            name: 'test', lensDirection: lens, sensorOrientation: sensor),
        orientation,
      );
      final model = _PreviewModel(controller);

      await tester.pumpWidget(ChangeNotifierProvider<CameraModel>.value(
        value: model,
        child: MaterialApp(
            home: Scaffold(
                body: Align(
          alignment: Alignment.bottomCenter,
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: const [
            Expanded(child: CameraPreviewOnly()),
            SizedBox(width: 100),
          ]),
        ))),
      ));
      await tester.pump();

      final viewport = tester.getRect(find.byType(CameraInteractionHandler));
      expect(viewport.width / viewport.height,
          closeTo(landscape ? 16 / 9 : 9 / 16, 0.001));
      // The raw landscape sensor must retain its own proportions before rotation.
      final texture =
          tester.getSize(find.byKey(const ValueKey('sensor-texture')));
      expect(texture.width / texture.height, closeTo(16 / 9, 0.001));

      void expectCorner(String source, String corner) {
        final point = tester.getCenter(find.byKey(ValueKey(source)));
        expect(
            (point.dx -
                    (corner.endsWith('right') ? viewport.right : viewport.left))
                .abs(),
            lessThan(11),
            reason: '$source must stay visible at $corner');
        expect(
            (point.dy -
                    (corner.startsWith('top') ? viewport.top : viewport.bottom))
                .abs(),
            lessThan(11),
            reason: '$source must stay visible at $corner');
      }

      expectCorner('sensor-top-left', topLeft);
      expectCorner('sensor-top-right', topRight);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      await controller.dispose();
    });
  }

  for (final (platform, lens) in [
    (TargetPlatform.iOS, CameraLensDirection.back),
    (TargetPlatform.iOS, CameraLensDirection.front),
    (TargetPlatform.android, CameraLensDirection.back),
  ]) {
    testWidgets('$platform $lens preserves the native portrait preview',
        (tester) async {
      final controller = _TextureController(
        CameraDescription(
            name: 'ios', lensDirection: lens, sensorOrientation: 90),
        DeviceOrientation.portraitUp,
      );
      final model = _PreviewModel(controller, androidSdkInt: 28);
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: SizedBox(
        width: 300,
        height: 1600 / 3,
        child: CameraInteractionHandler(model: model, controller: controller),
      ))));

      final viewport = tester.getRect(find.byType(CameraInteractionHandler));
      final texture =
          tester.getSize(find.byKey(const ValueKey('sensor-texture')));
      expect(texture.width / texture.height, closeTo(9 / 16, 0.001));
      final corner =
          tester.getCenter(find.byKey(const ValueKey('sensor-top-left')));
      expect(corner.dx, closeTo(viewport.left + 5, 0.001));
      expect(corner.dy, closeTo(viewport.top + 5, 0.001));
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      await controller.dispose();
    }, variant: TargetPlatformVariant.only(platform));
  }

  for (final width in [640.0, 1000.0]) {
    testWidgets('landscape at width $width preserves proportions and controls',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 360);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _TextureController(
        const CameraDescription(
            name: 'back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 90),
        DeviceOrientation.landscapeLeft,
      );
      final model = _PreviewModel(controller);
      await tester.pumpWidget(ChangeNotifierProvider<CameraModel>.value(
        value: model,
        child: const MaterialApp(
            home: Scaffold(
                body: Padding(
          padding: EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: CameraPreviewOnly(children: [
              SizedBox(key: ValueKey('switch-control'), width: 56, height: 56),
              SizedBox(width: 56, height: 56),
              SizedBox(key: ValueKey('zoom-control'), width: 50, height: 216),
            ])),
            SizedBox(width: 100),
          ]),
        ))),
      ));
      await tester.pump();
      final viewport = tester.getRect(find.byType(CameraInteractionHandler));
      expect(viewport.width / viewport.height, closeTo(16 / 9, 0.001));
      for (final key in ['switch-control', 'zoom-control']) {
        final control = find.byKey(ValueKey(key));
        expect(
            tester.getTopLeft(control).dy, greaterThanOrEqualTo(viewport.top));
        expect(tester.getBottomRight(control).dy,
            lessThanOrEqualTo(viewport.bottom));
        expect(tester.getBottomRight(control).dx,
            lessThanOrEqualTo(viewport.right));
      }
      expect(
          tester.getBottomRight(find.byKey(const ValueKey('zoom-control'))).dy,
          lessThan(tester.getTopLeft(find.text('Doppeltipp')).dy));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      await controller.dispose();
    });
  }
}
