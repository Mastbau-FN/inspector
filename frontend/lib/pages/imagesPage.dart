import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';

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

class ImageAddButton extends StatelessWidget {
  const ImageAddButton({
    Key? key,
    required ImagePicker picker,
    required this.onNewImages,
  })  : _picker = picker,
        super(key: key);

  final ImagePicker _picker;
  final Future<String?> Function(List<XFile> p1) onNewImages;

  @override
  Widget build(BuildContext context) {
    return uploadFromSystem();
  }

  FloatingActionButton uploadFromSystem() {
    return FloatingActionButton(
      child: Icon(Icons.add_a_photo),
      onPressed: () async {
        //XXX: multipicker is a great solution for now, but could be much better (maybe use adder fragment)
        final List<XFile>? new_images = await _picker.pickMultiImage();
        var resstring = await onNewImages(new_images ?? []);
        Fluttertoast.showToast(
          msg: resstring ??
              "upload finished (no idea of successed or failed tho)",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
        );
      },
    );
  }
}
