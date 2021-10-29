import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:inspector/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';

class ImageView extends StatelessWidget {
  List<Image> _images = [];
  final void Function(List<XFile>) onNewImages;
  final int columnCount;
  static void _defaultAdd(List<XFile> list) {
    Fluttertoast.showToast(
      msg: "This is a Toast message",
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
          //TODO: upload files
        },
      ),
    );
  }
}
