import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraModel with ChangeNotifier {
  static final CameraModel _instance = CameraModel._internal();
  factory CameraModel() => _instance;

  CameraModel._internal() {}

  Future<CameraController> get controller async => CameraController(
        // Get a specific camera from the list of available cameras.
        await currentCamera,
        // Define the resolution to use.
        ResolutionPreset.medium,
      );

  Future<CameraController> start() async {
    (await controller).initialize();
    return controller;
  }

  Future<List<CameraDescription>> all_cameras = availableCameras();

  Future<CameraDescription> get mainCamera async => (await all_cameras).first;

  Future<CameraDescription> get currentCamera => mainCamera; //XXX
}
