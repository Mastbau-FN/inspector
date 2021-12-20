import 'package:MBG_Inspektionen/classes/FuturedImageProvider.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:MBG_Inspektionen/fragments/imageWrap.dart';
import 'package:image_picker/image_picker.dart';

import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ImageView extends StatelessWidget {
  static final bool _experimental = false;
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

  ImageView.constant(
      {List<Image?>? images = const [],
      this.columnCount = 4,
      Key? key,
      this.onNewImages = _defaultAdd})
      : super(key: key) {
    this._images =
        images?.whereNotNull().map((e) => Future.value(e)).toList() ?? [];
  }

  ImageView.futured(
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
      body: FutureBuilder<List<Image>>(
          future: _experimental
              ? null
              : Future.wait(_images).then((a) => a.whereNotNull().toList()),
          builder: (context, snapshot) {
            if (!_experimental && !snapshot.hasData) return LoadingView();
            return PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: _experimental
                      ? FuturedImageProvider.fromFunc(
                          () async => (await _images[index])!.image)
                      : snapshot.data![index].image,
                  initialScale: PhotoViewComputedScale.contained * 0.8,
                  heroAttributes: PhotoViewHeroAttributes(tag: index),
                );
              },
              itemCount: _experimental ? _images.length : snapshot.data!.length,
              loadingBuilder: (context, event) => Center(
                child: LoadingView(),
              ),
              onPageChanged:
                  null, //seems interesting but no idea what its supposed to do 4now
            );
          }),
      floatingActionButton: FloatingActionButton(
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
      ),
    );
  }
}
