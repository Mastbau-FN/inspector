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

  Future<CameraController> get newController async => CameraController(
        // Get a specific camera from the list of available cameras.
        await currentCamera,
        // Define the resolution to use.
        ResolutionPreset.max,
      );

  CameraController? controller;

  Future<CameraController> start({bool reuse = true}) async {
    controller = await newController;
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

  Future<List<CameraDescription>> allCameras = availableCameras();

  Future<CameraDescription> get mainCamera async => (await allCameras).first;

  int _currentCameraIndex = 0;
  Future nextCamera() async {
    int len = (await allCameras).length;
    _currentCameraIndex++;
    _currentCameraIndex %= len;
  }

  Future prevCamera() async {
    int len = (await allCameras).length;
    _currentCameraIndex--;
    _currentCameraIndex %= len;
  }

  Future<CameraDescription> get currentCamera async {
    try {
      return (await allCameras)[_currentCameraIndex];
    } catch (e) {}

    return await mainCamera; //XXX (related to #202) use other lenses
  }
}
