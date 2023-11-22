import 'dart:io';
import 'dart:ui';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ImagesPage<T extends Object> extends StatelessWidget {
  late final List<Stream<ImageData<T>?>> _images;
  final Future<String?> Function(List<XFile>) onNewImages;
  final int columnCount;
  final bool hasMainImage;

  final bool intendsToAddPicture;

  static Future<String?> _defaultAdd(List<XFile> list) async {
    showToast(S.current!.notAvailable);
    return "";
  }

  static _default(Object _) => showToast(S.current!.notAvailable);

  // static _defaultDelete(Object id) async {
  //   try {
  //     if (kDebugMode)
  //       showToast((await API().deleteImageByHash(id.toString())).toString());
  //   } catch (e) {
  //     showToast(e.toString());
  //   }
  // }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  ImagesPage.constant({
    List<ImageData<T>?>? images = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
    this.intendsToAddPicture = false,
  }) : super(key: key) {
    this._images =
        images?.whereNotNull().map((e) => Stream.value(e)).toList() ?? [];
  }

  ImagesPage.futured({
    List<Future<ImageData<T>?>>? futureImages = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
    this.intendsToAddPicture = false,
  }) : super(key: key) {
    this._images =
        futureImages?.map((e) => Stream.fromFuture(e)).toList() ?? [];
  }

  ImagesPage.streamed({
    List<Stream<ImageData<T>?>>? imageStreams = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
    this.intendsToAddPicture = false,
  }) : super(key: key) {
    this._images = imageStreams ?? [];
  }

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          endDrawer: MainDrawer(),
          appBar: AppBar(
            title: Text('Bilder'),
          ),
          body: ImageWrap<T>.streamed(
            images: _images,
            onDelete: onDelete,
            onShare: onShare,
            onStar: onStar,
            hasFav: hasMainImage,
          ),
        ),
        ChangeNotifierProvider(
          create: (ocontext) => CameraModel(),
          child: Builder(builder: (context) {
            return ImageAddButton(
              picker: _picker,
              onNewImages: onNewImages,
              intended: intendsToAddPicture,
            );
          }),
        ),
      ],
    );
  }
}

class ImageAddButton extends StatefulWidget {
  final bool intended;

  const ImageAddButton({
    Key? key,
    required ImagePicker picker,
    required this.onNewImages,
    this.intended = false,
  })  : _picker = picker,
        super(key: key);

  final ImagePicker _picker;
  final Future<String?> Function(List<XFile> p1) onNewImages;

  @override
  State<ImageAddButton> createState() => _ImageAddButtonState();
}

class _ImageAddButtonState extends State<ImageAddButton>
    with SingleTickerProviderStateMixin {
  static const animationDuration = Duration(milliseconds: 200);

  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(duration: animationDuration, vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      });

    if (widget.intended) expand();
  }

  void expand() {
    controller.forward();
    expanded = true;
  }

  void collapse() {
    controller.reverse();

    closeCam();
    Future.delayed(animationDuration, () {
      setState(() {
        expanded = false;
        uploadingImage = false;
      });
    });
  }

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

  bool expanded = false;
  bool withCamera = false;
  bool uploadingImage = false;

  @override
  Widget build(BuildContext ocontext) {
    return BackdropFilter(
      filter: ImageFilter.blur(
          sigmaX: 5.0 * animation.value,
          sigmaY: 5.0 * animation.value,
          tileMode: TileMode.mirror),
      child: addImageButton(),
    );
  }

  Widget addImageButton() {
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
                  Stack(
                    alignment: Alignment.bottomRight,
                    //mainAxisSize: MainAxisSize.min,
                    children: [
                      if (expanded && !withCamera)
                        Transform.translate(
                          //transformHitTests: true,
                          offset: Offset(0, animation.value * -130),
                          child: Padding(
                            padding: const EdgeInsets.only(
                                top:
                                    160), //needed for hitTesting to work after transform
                            child: uploadFromSystem,
                          ),
                        ),
                      if (expanded)
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
                      add,
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

  void uploadShots(context) async {
    setState(() {
      uploadingImage = true;
    });
    String? resstring = await widget.onNewImages(queue);
    debugPrint(resstring);
    if (kDebugMode)
      showToast(resstring ??
          S.of(context).uploadFinishedNoIdeaWhetherSuccessedOrFailedTho);
    queue = [];
    collapse();
  }

  FloatingActionButton get add => FloatingActionButton(
        child: Icon(expanded ? Icons.cancel : Icons.add_a_photo),
        onPressed: expanded ? collapse : expand,
      );

  Widget takeImage(BuildContext context, CameraModel model) =>
      !withCamera || model.latestPic == null
          ? FloatingActionButton(
              child: Icon(withCamera ? Icons.camera : Icons.camera_alt),
              onPressed: withCamera ? () => shoot(context) : openCam,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ...queueButtonStuff,
                SizedBox(height: 5),
                photoDone,
                SizedBox(height: 5),
                discardPhoto,
              ],
            );

  List<Widget> get queueButtonStuff => [
        ...queue.asMap().entries.map((entry) {
          int idx = entry.key;
          XFile file = entry.value;
          return Transform.translate(
            offset: Offset(0, queue.length * 30 - 30.0 * idx),
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
        addToQueue,
      ];

  FloatingActionButton get uploadFromSystem => FloatingActionButton(
        child: Icon(Icons.folder),
        onPressed: () async {
          // multipicker is a great solution for now, but could be much better (maybe use adder fragment)
          final List<XFile>? newImages = await widget._picker.pickMultiImage();
          var resstring = await widget.onNewImages(newImages ?? []);
          if (kDebugMode)
            showToast(resstring ??
                S.of(context).uploadFinishedNoIdeaWhetherSuccessedOrFailedTho);
        },
      );

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
}

class FlashControlButton extends StatefulWidget {
  final CameraModel model;
  const FlashControlButton({
    super.key,
    required this.model,
  });

  @override
  State<FlashControlButton> createState() => _FlashControlButtonState();
}

class _FlashControlButtonState extends State<FlashControlButton> {
  var flash = false;
  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: () {
          flash
              ? widget.model.controller!.setFlashMode(FlashMode.torch)
              : widget.model.controller!.setFlashMode(FlashMode.off);
          setState(() => flash ^= true);
        },
        icon: Icon(
          !flash ? Icons.lightbulb : Icons.flash_off,
          color: Colors.white,
        ));
  }
}

class ZoomSlider extends StatelessWidget {
  final CameraModel model;
  const ZoomSlider({
    super.key,
    required this.model,
  });

  // double zoom = 1;
  zoomChanged(double newZoom) {
    // setState(() => zoom = newZoom);
    model.setZoom(newZoom);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(double, double)>(
        future: model.zoomRange,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Container();
          return SizedBox(
            height: 200,
            width: 50,
            child: RotatedBox(
              quarterTurns: 1,
              child: Consumer<ZoomModel>(builder:
                  (BuildContext context, ZoomModel value, Widget? child) {
                return Slider(
                  value: value.zoom,
                  min: snapshot.data!.$1,
                  max: snapshot.data!.$2,
                  onChanged: zoomChanged,
                );
              }),
            ),
          );
        });
  }
}
