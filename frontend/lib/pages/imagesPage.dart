import 'dart:io';
import 'dart:ui';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/generated/l10n.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ImagesPage<T extends Object> extends StatelessWidget {
  List<Stream<ImageData<T>?>> _images = [];
  final Future<String?> Function(List<XFile>) onNewImages;
  final int columnCount;
  final bool hasMainImage;

  static Future<String?> _defaultAdd(List<XFile> list) async {
    showToast(S.current.notAvailable);
    return "";
  }

  static _default(Object _) => showToast(S.current.notAvailable);

  static _defaultDelete(Object id) async {
    try {
      if (kDebugMode)
        showToast(
            (await Backend().deleteImageByHash(id.toString())).toString());
    } catch (e) {
      showToast(e.toString());
    }
  }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  ImagesPage.constant({
    List<ImageData<T>?>? images = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _defaultDelete,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
  }) : super(key: key) {
    this._images =
        images?.whereNotNull().map((e) => Stream.value(e)).toList() ?? [];
  }

  ImagesPage.futured({
    List<Future<ImageData<T>?>>? future_images = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _defaultDelete,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
  }) : super(key: key) {
    this._images =
        future_images?.map((e) => Stream.fromFuture(e)).toList() ?? [];
  }

  ImagesPage.streamed({
    List<Stream<ImageData<T>?>>? imageStreams = const [],
    this.columnCount = 4,
    Key? key,
    this.onNewImages = _defaultAdd,
    this.onDelete = _defaultDelete,
    this.onStar = _default,
    this.onShare = _default,
    this.hasMainImage = false,
  }) : super(key: key) {
    this._images = imageStreams ?? [];
  }

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text('Bilder'),
          ),
          body: ImageWrap<T>.futured(
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
            return ImageAddButton(picker: _picker, onNewImages: onNewImages);
          }),
        ),
      ],
    );
  }
}

class ImageAddButton extends StatefulWidget {
  const ImageAddButton({
    Key? key,
    required ImagePicker picker,
    required this.onNewImages,
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
                                    ? CameraPreviewOnly(
                                        children: [
                                          // Text('he, hier !!'),
                                          IconButton(
                                              onPressed: model.nextCamera,
                                              icon: Icon(
                                                Icons.switch_camera,
                                                color: Colors.white,
                                              )),
                                        ],
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

  void shoot(BuildContext context) async {
    CameraModel model = Provider.of<CameraModel>(context, listen: false);
    await model.shoot();
    debugPrint("photo taken");
  }

  void discardShot(context) =>
      Provider.of<CameraModel>(context, listen: false).discardPic();

  void uploadShot(context) async {
    setState(() {
      uploadingImage = true;
    });
    XFile? pic = Provider.of<CameraModel>(context, listen: false).latestPic;
    var resstring = pic != null
        ? await widget.onNewImages([pic])
        : S.of(context).sorryNoImageToUpload;
    debugPrint(resstring);
    if (kDebugMode)
      showToast(resstring ??
          S.of(context).uploadFinishedNoIdeaWhetherSuccessedOrFailedTho);
    collapse();
    discardShot(context);
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
                uploadPhoto,
                SizedBox(height: 5),
                discardPhoto,
              ],
            );

  FloatingActionButton get uploadFromSystem => FloatingActionButton(
        child: Icon(Icons.folder),
        onPressed: () async {
          // multipicker is a great solution for now, but could be much better (maybe use adder fragment)
          final List<XFile>? new_images = await widget._picker.pickMultiImage();
          var resstring = await widget.onNewImages(new_images ?? []);
          if (kDebugMode)
            showToast(resstring ??
                S.of(context).uploadFinishedNoIdeaWhetherSuccessedOrFailedTho);
        },
      );

  FloatingActionButton get discardPhoto => FloatingActionButton(
      backgroundColor: Colors.red,
      child: Icon(Icons.replay),
      onPressed: () => discardShot(context));

  FloatingActionButton get uploadPhoto => FloatingActionButton(
      backgroundColor: Colors.green,
      child: uploadingImage ? LoadingView() : Icon(Icons.check),
      onPressed: () => uploadShot(context));
}
