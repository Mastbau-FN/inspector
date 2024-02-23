import 'dart:io';

import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../backend/api.dart';
import '../classes/data/checkpoint.dart';
import '../helpers/toast.dart';
import '../l10n/locales.dart';
import '../pages/imagesPage.dart';
import 'adder.dart';
import 'camera/cameraModel.dart';
import 'camera/views/cameraMainPreview.dart';

class PrePhotoAdder extends StatelessWidget {
  final CheckPoint parent;
  Future<Null> Function() onDone;
  final CheckPointDefectsModel model;

  PrePhotoAdder({
    required this.parent,
    required this.onDone,
    required this.model,
  }) {
    this.parent;
  }
  @override
  Widget build(BuildContext context) {
    //dialog with camera
    return FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
              barrierDismissible: false,
              context: context,
              builder: (context) => ChangeNotifierProvider(
                  create: (context) => CameraModel(),
                  child: Builder(builder: (context) {
                    return CameraForAdder(
                        parent: parent, onDone: onDone, model: model);
                  })));
        });
  }
}

class CameraForAdder extends StatefulWidget {
  final parent;
  Future<Null> Function() onDone;

  final CheckPointDefectsModel model;
  @override
  CameraForAdder({
    Key? key,
    this.parent,
    required this.onDone,
    required this.model,
  }) : super(key: key);
  @override
  State<CameraForAdder> createState() => _CameraForAdderState();
}

class _CameraForAdderState extends State<CameraForAdder>
    with SingleTickerProviderStateMixin {
  static const animationDuration = Duration(milliseconds: 200);
  late Animation<double> animation;
  late AnimationController controller;
  void initState() {
    super.initState();
    openCam();
    controller = AnimationController(duration: animationDuration, vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });
  }

  bool firstOpen = true;
  bool uploadingImage = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        //XXX: ich verstehe nicht was hier abgeht, wenn wir den container haben geht der touch im hintergrund nicht mehr
        // Container(
        //   color: Colors.black.withOpacity(0.1 * animation.value),
        // ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (withCamera)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(25, 0, 8, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Consumer<CameraModel>(
                            builder: (context, model, child) =>
                                model.latestPic == null
                                    ? ChangeNotifierProvider.value(
                                        value: model.zoomM,
                                        child: Builder(builder: (context) {
                                          return cameraWithControls(model);
                                        }),
                                      )
                                    : Image.file(
                                        File(model.latestPic!.path),
                                        fit: BoxFit.fitWidth,
                                      ),
                          ),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Transform.translate(
                        //transformHitTests: true,
                        offset: Offset(0, animation.value * -70),
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top:
                                  100), //needed for hitTesting to work after transform
                          child: Consumer<CameraModel>(
                            builder: (context, model, child) =>
                                takeImage(context, model),
                          ),
                        ),
                      ),
                      SizedBox(height: 5),
                      addImgButton(context),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  FloatingActionButton addImgButton(BuildContext context) =>
      FloatingActionButton(
          child: Icon(Icons.cancel),
          onPressed: () {
            if (queue.isEmpty) {
              Provider.of<CameraModel>(context, listen: false).discardPic();
              closeCam();
              Navigator.of(context).pop();
              return;
            }
            Provider.of<CameraModel>(context, listen: false).latestPic =
                queue.last;
            queue.removeLast();
          });
  Widget takeImage(BuildContext context, CameraModel model) =>
      model.latestPic == null
          ? FloatingActionButton(
              child: Icon(withCamera ? Icons.camera : Icons.camera_alt),
              onPressed: withCamera ? () => shoot(context) : openCam,
            )
          : Column(
              verticalDirection: VerticalDirection.up,
              children: [
                photoDone,
                SizedBox(height: 5),
                discardPhoto,
                SizedBox(height: 5),
                addToQueue,
                Container(
                  height: 300,
                  child: Column(
                      verticalDirection: VerticalDirection.up,
                      children: [...queueButtonStuff]),
                ),
              ],
            );
  CameraPreviewOnly cameraWithControls(CameraModel model) {
    var switchCameraButton = IconButton(
        onPressed: model.nextCamera,
        icon: Icon(
          Icons.switch_camera,
          color: Colors.white,
        ));
    var flashButton = FlashControlButton(model: model);
    var zoomSlider = ZoomSlider(
      model: model,
    );
    return CameraPreviewOnly(
      children: [
        // Text('he, hier !!'),
        switchCameraButton,
        flashButton,
        zoomSlider,
      ],
    );
  }

  void shoot(BuildContext context) async {
    CameraModel model = Provider.of<CameraModel>(context, listen: false);
    await model.shoot();
    debugPrint("photo taken");
  }

  void discardShot(context) =>
      Provider.of<CameraModel>(context, listen: false).discardPic();

  List<XFile> queue = [];

  Future<void> addLatestToQueue(context) async {
    XFile? pic = Provider.of<CameraModel>(context, listen: false).latestPic;
    if (pic != null) {
      queue.add(pic);
      debugPrint("added to queue");
      discardShot(context);
    }
  }

  onNewImages(List<XFile> queue, CheckPointDefect cp) async {
    //showToast(S.of(context).newImageSendingThisMayTakeASec);

    //widget.model.currentlyChosenChildId = widget.parent.id;
    // var value = await widget.model.updateCurrentChild(
    //   (data) async {
    //     var ret =
    await API().uploadNewImagesOrFiles(cp, queue,
        caller: widget.model.currentData, forceUpdate: true);
    // await Future.delayed(Duration(seconds: 5));
    //     return ret;
    //   },
    // );
    // debugPrint("value: $value");
    // return value;
  }

  void uploadShots(context) async {
    setState(() {
      uploadingImage = true;
    });

    // Navigator.of(context).pop();
    // route to checkpointdefects.adders

    // var model = Provider.of<CheckPointDefectsModel>(context);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (ncontext) =>
            // ChangeNotifierProvider<CheckPointDefectsModel>.value(
            // value: model,
            // child:
            Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CheckPointDefectsModel.adder(
              parent: widget.parent,
              onDone: (defect) async {
                CheckPointDefect? newDefect =
                    await API().setNew(defect, caller: widget.parent);
                // CheckPointDefectsModel model =
                //     Provider.of<CheckPointDefectsModel>(ncontext);
                await API().update(newDefect!);
                await widget.onDone();
                await onNewImages(queue, newDefect);
                await widget.onDone();
                queue = [];
              },
              onCancel: () {
                Navigator.of(ncontext).pop();
              },
            ),
          ),
        ),
        // ),
      ),
    );
    closeCam();
  }

  List<Widget> get queueButtonStuff => [
        ...queue.asMap().entries.map((entry) {
          int idx = entry.key;
          XFile file = entry.value;
          return Transform.translate(
            offset: Offset(0, -(-25 + 30 * queue.length - (80.0) * idx)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 50,
                width: 50,
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          );
        }),
        // SizedBox(height: 15),
      ];
  FloatingActionButton get discardPhoto => FloatingActionButton(
      backgroundColor: Colors.red,
      child: Icon(Icons.replay),
      onPressed: () => discardShot(context));

  FloatingActionButton get photoDone => FloatingActionButton(
        backgroundColor: Colors.green,
        child: uploadingImage ? LoadingView() : Icon(Icons.check),
        onPressed: () =>
            addLatestToQueue(context).then((value) => uploadShots(context)),
      );

  Widget get addToQueue => uploadingImage
      ? Container()
      : FloatingActionButton(
          backgroundColor: Colors.blue,
          child: Icon(Icons.add_photo_alternate),
          onPressed: () => addLatestToQueue(context),
        );

  bool withCamera = false;
  void openCam() {
    debugPrint("opened camera");
    setState(() {
      withCamera = true;
    });
  }

  void closeCam() {
    debugPrint("closed camera");
    setState(() {
      withCamera = false;
    });
  }

  void secondOpen() {
    setState(() {
      firstOpen = false;
    });
  }
}
