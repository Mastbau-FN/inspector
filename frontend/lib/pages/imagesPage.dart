import 'package:MBG_Inspektionen/fragments/camera/cameraModel.dart';
import 'package:MBG_Inspektionen/fragments/camera/views/cameraMainPreview.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ImagesPage extends StatelessWidget {
  List<Future<Image?>> _images = [];
  final Future<String?> Function(List<XFile>) onNewImages;
  final int columnCount;
  static Future<String?> _defaultAdd(List<XFile> list) async {
    Fluttertoast.showToast(
      msg: "no callback provided",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
    return "";
  }

  ImagesPage.constant(
      {List<Image?>? images = const [],
      this.columnCount = 4,
      Key? key,
      this.onNewImages = _defaultAdd})
      : super(key: key) {
    this._images =
        images?.whereNotNull().map((e) => Future.value(e)).toList() ?? [];
  }

  ImagesPage.futured(
      {List<Future<Image?>>? future_images = const [],
      this.columnCount = 4,
      Key? key,
      this.onNewImages = _defaultAdd})
      : super(key: key) {
    this._images = future_images ?? [];
  }

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bilder'),
      ),
      body: ImageWrap.futured(images: _images),
      floatingActionButton:
          ImageAddButton(picker: _picker, onNewImages: onNewImages),
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

class _ImageAddButtonState extends State<ImageAddButton> {
  bool expanded = false;
  bool withCamera = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CameraModel(),
      child: Align(
        alignment: Alignment.bottomCenter,
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
                    child: CameraPreviewOnly(),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expanded) takeImage(context),
                SizedBox(height: 2),
                if (expanded && !withCamera) uploadFromSystem,
                SizedBox(height: 8),
                add,
              ],
            ),
          ],
        ),
      ),
    );
  }

  FloatingActionButton get add => FloatingActionButton(
        child: Icon(expanded ? Icons.cancel : Icons.add_a_photo),
        onPressed: () {
          setState(() {
            expanded ^= true;
            if (!expanded) withCamera = false;
          });
        },
      );

  FloatingActionButton takeImage(BuildContext context) => FloatingActionButton(
        child: Icon(withCamera ? Icons.camera : Icons.camera_alt),
        onPressed: () async {
          if (withCamera) {
            CameraModel model = Provider.of<CameraModel>(context,
                listen: false); //TODO: irgendwie passiert hier nichts..
            XFile file = await model.shoot();
            var resstring = await widget.onNewImages([file]);
            Fluttertoast.showToast(
              msg: resstring ??
                  "upload finished (no idea whether successed or failed tho)",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
            );
          } else {
            setState(() {
              withCamera = true;
            });
          }
        },
      );

  FloatingActionButton get uploadFromSystem => FloatingActionButton(
        child: Icon(Icons.folder),
        onPressed: () async {
          //XXX: multipicker is a great solution for now, but could be much better (maybe use adder fragment)
          final List<XFile>? new_images = await widget._picker.pickMultiImage();
          var resstring = await widget.onNewImages(new_images ?? []);
          Fluttertoast.showToast(
            msg: resstring ??
                "upload finished (no idea of successed or failed tho)",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
          );
        },
      );
}
