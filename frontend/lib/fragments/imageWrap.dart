import 'package:flutter/material.dart';

class ImageWrap extends StatelessWidget {
  final List<Image> images;
  final int columnCount;
  ImageWrap({required this.images, this.columnCount = 4, Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: images
          .map((e) => SizedBox(
                height: 100,
                width: 100,
                child: e,
              ))
          .toList(),
    );
  }
}
