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

  Widget _previewWithChildren(CameraController cc, CameraModel model) =>
      children.isEmpty
          ? CameraPreview(cc)
          : Stack(
              alignment: Alignment.topRight,
              children: [
                ZoomDetect(
                  model: model,
                  cc: cc,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  // direction: Axis.horizontal,
                  // alignment: WrapAlignment.end,
                  // crossAxisAlignment: WrapCrossAlignment.end,
                ),
              ],
            );

  @override
  Widget build(BuildContext context) => Material(
        //FIXME: why the hell would i need a Material, it should be an ancestor already..
        child: Consumer<CameraModel>(
          builder: (context, model, child) {
            return FutureBuilder(
              future: model.start(),
              builder: (context, AsyncSnapshot<CameraController> snapshot) =>
                  // LoadingView(),
                  switch ((snapshot.connectionState, snapshot.data)) {
                (ConnectionState.done, CameraController cc) =>
                  _previewWithChildren(cc, model),
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

class ZoomDetect extends StatefulWidget {
  final CameraModel model;
  final CameraController cc;
  ZoomDetect({
    super.key,
    required this.model,
    required this.cc,
  });

  @override
  State<ZoomDetect> createState() => _ZoomDetectState();
}

class _ZoomDetectState extends State<ZoomDetect> {
  var startZoom = 1.0;

  Offset? focusPoint;

  @override
  Widget build(BuildContext context) {
    return Consumer<ZoomModel>(
      builder: (context, zoomModel, child) => GestureDetector(
        onScaleStart: (zoomDelta) {
          startZoom = zoomModel.zoom;
        },
        onScaleUpdate: (zoomDelta) {
          // debugPrint(zoomDelta.toString());
          try {
            var newZoom = startZoom * zoomDelta.scale;
            if (newZoom < zoomModel.zoomRange.$1 ||
                newZoom > zoomModel.zoomRange.$2) {
              throw Exception("zoom out of bounds");
            }
            // debugPrint(
            //     "newZoom: $newZoom = zoomDelta: ${zoomDelta.scale} + oldZoom: ${zoomModel.zoom}");
            widget.model.setZoom(newZoom);
          } catch (e) {}
        },
        onTapDown: (details) {
          // debugPrint(details.localPosition.toString());
          setState(() {
            this.focusPoint = details.localPosition;
          });
          RenderBox box = context.findRenderObject()! as RenderBox;
          final Offset focusPoint = Offset(
            details.localPosition.dx / box.size.width,
            details.localPosition.dy / box.size.height,
          );
          widget.model.focus(focusPoint);
        },
        onTapUp: (details) {
          Future.delayed(Duration(milliseconds: 500)).then((value) {
            setState(() {
              this.focusPoint = null;
            });
          });
        },
        onDoubleTap: widget.model.nextCamera,
        child: child,
      ),
      child: Stack(
        children: [
          CameraPreview(widget.cc),
          if (focusPoint != null)
            Positioned(
              left: focusPoint!.dx,
              top: focusPoint!.dy,
              child: // focus border square
                  Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
