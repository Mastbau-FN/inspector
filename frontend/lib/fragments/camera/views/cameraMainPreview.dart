import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraPreviewOnly extends StatelessWidget {
  const CameraPreviewOnly({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraModel>(builder: (context, model, child) {
      return FutureBuilder(
        future: model.start(),
        builder: (context, AsyncSnapshot<CameraController> snapshot) =>
            // LoadingView(),
            snapshot.connectionState == ConnectionState.done &&
                    snapshot.data != null
                ? CameraPreview(snapshot.data!)
                : LoadingView(),
      );
    });
  }
}
