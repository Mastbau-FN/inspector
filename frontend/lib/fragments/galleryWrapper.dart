import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'loadingscreen/loadingView.dart';

class GalleryPhotoViewWrapper extends StatefulWidget {
  GalleryPhotoViewWrapper({
    this.loadingBuilder,
    this.backgroundDecoration,
    this.minScale,
    this.maxScale,
    this.initialIndex = 0,
    required this.galleryItems,
    this.scrollDirection = Axis.horizontal,
  }) : pageController = PageController(initialPage: initialIndex);

  final LoadingBuilder? loadingBuilder;
  final BoxDecoration? backgroundDecoration;
  final dynamic minScale;
  final dynamic maxScale;
  final int initialIndex;
  final PageController pageController;
  final List<ImageItem> galleryItems;
  final Axis scrollDirection;

  @override
  State<StatefulWidget> createState() {
    return _GalleryPhotoViewWrapperState();
  }
}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
  late int currentIndex = widget.initialIndex;

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: widget.backgroundDecoration,
        constraints: BoxConstraints.expand(
          height: MediaQuery.of(context).size.height,
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: <Widget>[
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: _buildItem,
              itemCount: widget.galleryItems.length,
              loadingBuilder: widget.loadingBuilder,
              backgroundDecoration: widget.backgroundDecoration,
              pageController: widget.pageController,
              onPageChanged: onPageChanged,
              scrollDirection: widget.scrollDirection,
            ),
            Container(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                "Image ${currentIndex + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17.0,
                  decoration: null,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  PhotoViewGalleryPageOptions _buildItem(BuildContext context, int index) {
    final ImageItem item = widget.galleryItems[index];
    return (item.image == null)
        ? PhotoViewGalleryPageOptions.customChild(
            child: item.fallBackWidget,
            childSize: const Size(300, 300),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
            maxScale: PhotoViewComputedScale.covered * 4.1,
            heroAttributes: PhotoViewHeroAttributes(tag: item.tag),
          )
        : PhotoViewGalleryPageOptions(
            imageProvider: item.image,
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
            maxScale: PhotoViewComputedScale.covered * 4.1,
            heroAttributes: PhotoViewHeroAttributes(tag: item.tag),
          );
  }
}

class ImageItem<T extends Object> with ChangeNotifier {
  Widget fallBackWidget;
  ImageProvider? image;
  Object tag;
  @deprecated
  /* const */ ImageItem.fromImage(Image? image,
      {required this.tag,
      this.fallBackWidget =
          const Center(child: const Icon(Icons.report_problem))})
      : this.image = image?.image;

  /* const */ ImageItem.fromImageData(ImageData<T>? imaged,
      {this.fallBackWidget =
          const Center(child: const Icon(Icons.report_problem))})
      : this.image = imaged?.image.image,
        this.tag = imaged?.id ?? UniqueKey();

  @deprecated
  ImageItem.fromFutureImage(Future<Image?> image,
      {required this.tag, this.fallBackWidget = const LoadingView()}) {
    image.then((value) {
      this.image = value?.image;
      this.fallBackWidget = Center(child: const Icon(Icons.report_problem));
      notifyListeners();
    });
  }

  ImageItem.fromFutureImageData(
    Future<ImageData<T>?> image, {
    fallBackWidget = const LoadingView(),
  })  : this.tag = UniqueKey(),
        this.fallBackWidget = Center(child: const Icon(Icons.report_problem)) {
    image.then((value) {
      this.image = value?.image.image;
      if (value != null) this.tag = value.id;
      notifyListeners();
    });
  }
}
