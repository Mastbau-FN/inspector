import 'package:MBG_Inspektionen/fragments/camera/cameramodel.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CameraMainPreview extends StatelessWidget {
  const CameraMainPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CameraModel>(
      create: (_) => CameraModel(),
      child: Builder(builder: (context) {
        return FutureBuilder(
          future: context.watch<CameraModel>().start(),
          builder: (context, AsyncSnapshot<CameraController> snapshot) =>
              // LoadingView(),
              snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null
                  ? CameraPreview(snapshot.data!)
                  : LoadingView(),
        );
      }),
    );
  }
}
