import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraModel extends ChangeNotifier {
  Future<CameraController> get new_controller async => CameraController(
        // Get a specific camera from the list of available cameras.
        await currentCamera,
        // Define the resolution to use.
        ResolutionPreset.medium,
      );

  CameraController? controller;

  Future<CameraController> start({bool reuse = true}) async {
    controller = await new_controller;
    await controller!.initialize();
    return controller!;
  }

  XFile? _latestPic;

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

  Future<List<CameraDescription>> all_cameras = availableCameras();

  Future<CameraDescription> get mainCamera async => (await all_cameras).first;

  Future<CameraDescription> get currentCamera => mainCamera; //XXX
}
