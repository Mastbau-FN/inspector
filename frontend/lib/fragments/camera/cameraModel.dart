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
    controller = await newController;
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
    if (controller == null) {
      debugPrint("we need a new cameraController");
      await start();
    }
    _latestPic = await controller!.takePicture();
    notifyListeners();
    return latestPic!;
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
  Future nextCamera() async {
    int len = (await allCameras).length;
    _currentCameraIndex++;
    _currentCameraIndex %= len;
    controller = await newController;
    notifyListeners();
  }

  Future prevCamera() async {
    int len = (await allCameras).length;
    _currentCameraIndex--;
    _currentCameraIndex %= len;
    controller = await newController;
    notifyListeners();
  }

  Future<CameraDescription?> get currentCamera async {
    try {
      return (await allCameras)[_currentCameraIndex];
    } catch (e) {}

    return await mainCamera; //XXX (related to #202) use other lenses
  }
}
