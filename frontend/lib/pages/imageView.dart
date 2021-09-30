import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:mastbau_inspector/fragments/imageWrap.dart';

class ImageView extends StatelessWidget {
  List<Image> _images = [];
  final int columnCount;
  ImageView({List<Image?>? images = const [], this.columnCount = 4, Key? key})
      : super(key: key) {
    this._images = images?.whereNotNull().toList() ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bilder'),
      ),
      body: ImageWrap(
        images: _images,
      ),
    );
  }
}
