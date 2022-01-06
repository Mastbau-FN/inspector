import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraModel extends ChangeNotifier {
  Future<CameraController> get new_controller async => CameraController(
        // Get a specific camera from the list of available cameras.
        await currentCamera,
        // Define the resolution to use.
        ResolutionPreset.medium,
      );

  CameraController? controller;

  Future<CameraController> start({bool reuse = true}) async {
    var controller = await new_controller;
    await controller.initialize();
    return controller;
  }

  Future<XFile> shoot() async {
    if (controller == null) await start();
    return await controller!.takePicture();
  }

  Future<List<CameraDescription>> all_cameras = availableCameras();

  Future<CameraDescription> get mainCamera async => (await all_cameras).first;

  Future<CameraDescription> get currentCamera => mainCamera; //XXX
}
