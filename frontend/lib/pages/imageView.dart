import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:mastbau_inspector/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';

class ImageView extends StatelessWidget {
  List<Image> _images = [];
  final int columnCount;
  ImageView({List<Image?>? images = const [], this.columnCount = 4, Key? key})
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
          //XXX: multipicker is a great solution for now, but could be much better (maybe use the floatingbutton transform from my kruemel_reiten app)
          final List<XFile>? new_images = await _picker.pickMultiImage();
          //TODO: upload files
        },
      ),
    );
  }
}
