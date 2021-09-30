import 'package:flutter/material.dart';

class ImageView extends StatelessWidget {
  List<Image> _images = [];
  final int columnCount;
  ImageView({List<Image?> images = const [], this.columnCount = 4, Key? key})
      : super(key: key) {
    this._images = (images.where((el) => el != null) as List<Image>);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: _images,
    );
  }
}
