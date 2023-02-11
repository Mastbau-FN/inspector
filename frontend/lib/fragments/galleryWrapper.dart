import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';

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
      appBar: AppBar(),
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
                "Image ${currentIndex + 1}:${widget.galleryItems[currentIndex].image?.id.toString().split('/').last ?? ')'}",
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
    return PhotoViewGalleryPageOptions.customChild(
      child: FullImg(item: item),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained * (0.5 + index / 10),
      maxScale: PhotoViewComputedScale.covered * 4.1,
      heroAttributes: PhotoViewHeroAttributes(tag: item.tag),
    );
  }
}

class FullImg extends StatelessWidget {
  final ImageItem item;
  const FullImg({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: item,
      builder: (context, child) => FutureBuilder(
        future: item.image?.fullImage(),
        builder: (context, AsyncSnapshot<Image?> snapshot) =>
            snapshot.data ??
            item.image?.thumbnail ??
            ((snapshot.hasError)
                ? item.fallBackWidget
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      if (item.image != null) item.image!.thumbnail,
                      const LoadingView(),
                    ],
                  )),
      ),
    );
  }
}

class ImageItem<T extends Object> with ChangeNotifier {
  Widget fallBackWidget;
  ImageData? image;
  Object tag;

  /* const */ ImageItem.fromImageData(ImageData<T>? imaged,
      {this.fallBackWidget =
          const Center(child: const Icon(Icons.report_problem))})
      : this.image = imaged,
        this.tag = imaged?.id ?? UniqueKey();

  ImageItem.fromFutureImageData(
    Future<ImageData<T>?> image, {
    fallBackWidget = const LoadingView(),
  })  : this.tag = UniqueKey(),
        this.fallBackWidget = Center(child: const Icon(Icons.report_problem)) {
    image.then((value) {
      this.image = value;
      if (value != null) this.tag = value.id;
      // debugPrint(this.tag.toString());
      notifyListeners();
    });
  }

  ImageItem.fromImageDataStream(
    Stream<ImageData<T>?> image, {
    fallBackWidget = const LoadingView(),
  })  : this.tag = UniqueKey(),
        this.fallBackWidget = const LoadingView() {
    image.forEach((value) {
      this.image = value;
      if (value != null)
        this.tag = value.id;
      else
        this.fallBackWidget = Center(child: const Icon(Icons.report_problem));
      // debugPrint(this.tag.toString());
      notifyListeners();
    });
  }
}
