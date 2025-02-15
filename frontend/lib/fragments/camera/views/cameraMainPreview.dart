import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../widgets/error.dart';
import 'package:flutter/material.dart';

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

@override
class _ZoomDetectState extends State<ZoomDetect> {
  double startZoom = 1.0;
  Offset? focusPoint;
  static const EventChannel volumeButtonChannel =
      EventChannel('volume_button_events');

  @override
  void initState() {
    super.initState();
    _listenForVolumeButtons();
  }

  void _listenForVolumeButtons() {
    volumeButtonChannel.receiveBroadcastStream().listen((event) {
      if (event == "volume_up") {
        _adjustZoom(0.1); // Increase zoom
      } else if (event == "volume_down") {
        _adjustZoom(-0.1); // Decrease zoom
      }
    }, onError: (error) {
      debugPrint("Error receiving volume button events: $error");
    });
  }

  void _adjustZoom(double zoomStep) async {
    double newZoom = (widget.model.zoom + zoomStep).clamp(
        widget.model.zoomM.zoomRange.$1, widget.model.zoomM.zoomRange.$2);
    await widget.model.setZoom(newZoom);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (zoomDelta) {
        startZoom = widget.model.zoom;
      },
      onScaleUpdate: (zoomDelta) {
        double newZoom = (startZoom * zoomDelta.scale).clamp(
            widget.model.zoomM.zoomRange.$1, widget.model.zoomM.zoomRange.$2);
        widget.model.setZoom(newZoom);
      },
      onTapDown: (details) {
        setState(() {
          this.focusPoint = details.localPosition;
        });

        RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box == null || box.size.isEmpty) return;

        final Offset focusPoint = Offset(
          details.localPosition.dx / box.size.width,
          details.localPosition.dy / box.size.height,
        );
        widget.model.focus(focusPoint);
      },
      onTapUp: (details) {
        Future.delayed(Duration(milliseconds: 500)).then((_) {
          if (mounted) {
            setState(() {
              focusPoint = null;
            });
          }
        });
      },
      onDoubleTap: () async {
        await widget.model.nextCamera();
      },
      child: Stack(
        children: [
          CameraPreview(widget.cc),
          if (focusPoint != null)
            Positioned(
              left: focusPoint!.dx,
              top: focusPoint!.dy,
              child: Container(
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
