import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:flutter/material.dart';

class ImageWrap extends StatelessWidget {
  final List<Future<Image?>> images;
  final int columnCount;
  ImageWrap.constant(
      {List<Image> images = const [], this.columnCount = 4, Key? key})
      : this.images = images.map((e) => Future.value(e)).toList(),
        super(key: key);
  ImageWrap.futured({required this.images, this.columnCount = 4, Key? key})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: images
          .map((e) => SizedBox(
                height: 100,
                width: 100,
                child: FutureBuilder(
                  future: e,
                  builder: (BuildContext context, AsyncSnapshot<Image?> snap) =>
                      snap.data ??
                      (snap.hasError
                          ? Icon(Icons.report_problem)
                          : LoadingView() //hm this gets also triggered if the snapshot completed, but no image could be parsed

                      ),
                ),
              ))
          .toList(),
    );
  }
}

class ImageData {
  Image? image;
}

class ImageView extends StatelessWidget {
  final ImageData img;
  const ImageView({required this.img, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: img.image,
    );
  }
}
