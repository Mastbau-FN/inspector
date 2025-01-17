import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraModel extends ChangeNotifier {
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   // App state changed before we got the chance to initialize.
  //   if (controller == null || !controller.value.isInitialized) {
  //     return;
  //   }
  //   if (state == AppLifecycleState.inactive) {
  //     controller?.dispose();
  //   } else if (state == AppLifecycleState.resumed) {
  //     if (controller != null) {
  //       onNewCameraSelected(controller.description);
  //     }
  //   }
  // }

  Future<CameraController?> get newController async =>
      switch (await currentCamera) {
        null => null,
        CameraDescription cd => CameraController(
            // Get a specific camera from the list of available cameras.
            cd,
            // Define the resolution to use.
            ResolutionPreset.max,
          )
      };

  CameraController? controller;

  Future<CameraController> start({bool reuse = true}) async {
    if (reuse && controller != null && controller!.value.isInitialized) {
      return controller!;
    }
    controller = await newController;
    if (controller == null) {
      throw Exception("Failed to initialize camera");
    }
    await controller!.initialize();
    return controller!;
  }

  XFile? _latestPic;

  /// only use on weird edge cases, this normally gets set by [shoot]
  set latestPic(XFile? value) {
    _latestPic = value;
    notifyListeners();
  }

  XFile? get latestPic => _latestPic;
  void discardPic() {
    debugPrint("discarded picture");
    _latestPic = null;
    notifyListeners();
  }

  Future<XFile> shoot() async {
    if (controller == null || !controller!.value.isInitialized) {
      debugPrint("Controller nicht initialisiert, starte Kamera...");
      await start();
    }
    try {
      _latestPic = await controller!.takePicture();
      notifyListeners();
      return latestPic!;
    } catch (e) {
      debugPrint("Fehler beim Aufnehmen des Bildes: $e");
      throw Exception("Fehler beim Aufnehmen des Bildes");
    }
  }

  Future<List<CameraDescription>> get allCameras async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        throw Exception("no cameras available");
      }
      return cams;
    } catch (e) {
      showToast("Keine Kamera verfügbar");
      debugPrint(e.toString());
    }
    return [];
  }

  Future<CameraDescription?> get mainCamera async =>
      (await allCameras).firstOrNull;

  int _currentCameraIndex = 0;
  Future<void> nextCamera() async {
    final cameras = await allCameras;
    if (cameras.isEmpty) {
      showToast("Keine Kameras verfügbar");
      return;
    }
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    controller = await newController;
    notifyListeners();
  }

  Future<void> prevCamera() async {
    final cameras = await allCameras;
    if (cameras.isEmpty) {
      showToast("Keine Kameras verfügbar");
      return;
    }
    _currentCameraIndex =
        (_currentCameraIndex - 1 + cameras.length) % cameras.length;
    controller = await newController;
    notifyListeners();
  }

  Future<(double, double)> get zoomRange async {
    // return (1.0, 2.0);
    controller = await start();
    final maxZoom = await controller!.getMaxZoomLevel();
    final minZoom = await controller!.getMinZoomLevel();
    zoomM.zoomRange = (minZoom, maxZoom);
    return (minZoom, maxZoom);
  }

  final zoomM = ZoomModel();
  double get zoom => zoomM.zoom;

  Future<void> setZoom(newVal) async {
    zoomM.zoom = newVal;
    controller ??= await start();
    controller!.setZoomLevel(newVal);
    // notifyListeners();
  }

  @override
  void dispose() {
    disposeCamera();
    super.dispose();
  }

  void disposeCamera() {
    if (controller != null) {
      controller!.setFlashMode(FlashMode.off).catchError((e) {
        debugPrint("Fehler beim Ausschalten des Blitzes: $e");
      });
      controller!.dispose();
      controller = null;
    }
  }

  Future<void> focus(Offset focusPoint) async {
    controller ??= await start();
    controller!.setFocusPoint(focusPoint);
    controller!.setExposurePoint(focusPoint);
  }

  Future<CameraDescription?> get currentCamera async {
    try {
      return (await allCameras)[_currentCameraIndex];
    } catch (e) {}

    return await mainCamera; //XXX (related to #202) use other lenses
  }
}

class ZoomModel extends ChangeNotifier {
  (double, double) zoomRange = (1.0, 2.0);
  double _zoom = 1.0;
  double get zoom => _zoom;
  set zoom(newVal) {
    _zoom = newVal;
    debugPrint("zoom: $newVal");
    notifyListeners();
    // Future.delayed(Duration(milliseconds: 100), () => notifyListeners());
  }
}

extension ToRangeValues on (double, double) {
  RangeValues toRangeValues() => RangeValues(this.$1, this.$2);
}
