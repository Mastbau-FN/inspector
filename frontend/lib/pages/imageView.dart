import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:inspector/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';

class ImageView extends StatelessWidget {
  List<Image> _images = [];
  final Future Function(List<XFile>) onNewImages;
  final int columnCount;
  static Future _defaultAdd(List<XFile> list) async {
    Fluttertoast.showToast(
      msg: "no callback provided",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
  }

  ImageView(
      {List<Image?>? images = const [],
      this.columnCount = 4,
      Key? key,
      this.onNewImages = _defaultAdd})
      : super(key: key) {
    this._images = images?.whereNotNull().toList() ?? [];
  }

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bilder'),
      ),
      body: ImageWrap(
        images: _images,
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add_a_photo),
        onPressed: () async {
          //XXX: multipicker is a great solution for now, but could be much better (maybe use adder fragment)
          final List<XFile>? new_images = await _picker.pickMultiImage();
          await onNewImages(new_images ?? []);
          Fluttertoast.showToast(
            msg: "upload finished (no idea of successed or failed tho)",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
          );
        },
      ),
    );
  }
}
