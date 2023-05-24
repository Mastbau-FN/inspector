import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/error.dart';

class CameraPreviewOnly extends StatelessWidget {
  final List<Widget> children;
  const CameraPreviewOnly({this.children = const [], Key? key})
      : super(key: key);

  Widget _previewWithChildren(CameraController cc) => children.isEmpty
      ? CameraPreview(cc)
      : Stack(
          alignment: Alignment.topRight,
          children: [
            CameraPreview(cc),
            Wrap(children: children),
          ],
        );

  @override
  Widget build(BuildContext context) => Material(
        //why the hell would i need a Material, it should be an ancestor already..
        child: Consumer<CameraModel>(
          builder: (context, model, child) {
            return FutureBuilder(
              future: model.start(),
              builder: (context, AsyncSnapshot<CameraController> snapshot) =>
                  // LoadingView(),
                  switch ((snapshot.connectionState, snapshot.data)) {
                (ConnectionState.done, CameraController cc) =>
                  _previewWithChildren(cc),
                (ConnectionState.done, null) => ErrorText("no camera"),
                (ConnectionState.waiting, _) => LoadingView(),
                (ConnectionState.active, _) => LoadingView(),
                (ConnectionState.none, _) => ErrorText("no camera"),
              },
            );
          },
        ),
      );
}
