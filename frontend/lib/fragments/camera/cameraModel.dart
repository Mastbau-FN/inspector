import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraModel extends ChangeNotifier {
  Future<CameraController> get controller async => CameraController(
        // Get a specific camera from the list of available cameras.
        await currentCamera,
        // Define the resolution to use.
        ResolutionPreset.medium,
      );

  Future<CameraController> start() async {
    var c = await controller;
    await c.initialize();
    return c;
  }

  Future<List<CameraDescription>> all_cameras = availableCameras();

  Future<CameraDescription> get mainCamera async => (await all_cameras).first;

  Future<CameraDescription> get currentCamera => mainCamera; //XXX
}
