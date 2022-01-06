import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraModel with ChangeNotifier {
  static final CameraModel _instance = CameraModel._internal();
  factory CameraModel() => _instance;

  CameraModel._internal() {
    asyncinit();
  }

  void asyncinit() async {
    all_cameras = await availableCameras();

    camerasready = true;
    notifyListeners();
  }

  CameraController? get controller => currentCamera != null
      ? CameraController(
          // Get a specific camera from the list of available cameras.
          currentCamera!,
          // Define the resolution to use.
          ResolutionPreset.medium,
        )
      : null;

  bool camerasready = false;

  Future start() async {
    await Future.doWhile(() async {
      if (controller != null) return true;
      await Future.delayed(Duration(microseconds: 200));
      return controller != null;
    });
  }

  List<CameraDescription>? all_cameras;

  CameraDescription? get mainCamera => all_cameras?.first;

  CameraDescription? get currentCamera => mainCamera; //XXX
}
