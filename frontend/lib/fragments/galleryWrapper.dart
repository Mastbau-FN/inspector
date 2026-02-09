import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter/scheduler.dart';

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
    String currentName() {
      final explicit = widget.galleryItems[currentIndex].image?.name;
      if (explicit != null && explicit.trim().isNotEmpty) return explicit.trim();
      final id = widget.galleryItems[currentIndex].image?.id.toString();
      if (id == null || id.isEmpty) return '';
      final parts = id.split('/').where((e) => e.isNotEmpty).toList();
      return parts.isEmpty ? id : parts.last;
    }

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
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      currentName().isEmpty
                          ? 'Bild ${currentIndex + 1}'
                          : 'Bild ${currentIndex + 1}: ${currentName()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                        decoration: null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
      // Keep consistent minimum scale. The previous index-based minScale could clamp initialScale
      // and make some images appear zoomed-in by default.
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 4.1,
      heroAttributes: PhotoViewHeroAttributes(tag: item.tag),
    );
  }
}

class FullImg extends StatelessWidget {
  final ImageItem item;
  const FullImg({super.key, required this.item});

  Widget _safe(Image img) {
    return Image(
      image: img.image,
      fit: BoxFit.contain,
      filterQuality: img.filterQuality,
      isAntiAlias: img.isAntiAlias,
      gaplessPlayback: img.gaplessPlayback,
      errorBuilder: (context, error, stackTrace) {
        // Mark corrupt/unreadable images so they disappear from the gallery.
        // Defer notify to avoid setState during build.
        SchedulerBinding.instance
            .addPostFrameCallback((_) => item.markCorrupt());
        return item.fallBackWidget;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: item,
      builder: (context, child) => FutureBuilder(
        future: item.image?.fullImage(),
        builder: (context, AsyncSnapshot<Image?> snapshot) {
          if (snapshot.hasError) {
            SchedulerBinding.instance
                .addPostFrameCallback((_) => item.markCorrupt());
            return item.fallBackWidget;
          }
          return (snapshot.data != null)
              ? _safe(snapshot.data!)
              : (item.image?.image != null)
                  ? _safe(item.image!.image)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        if (item.image != null) _safe(item.image!.image),
                        const LoadingView(),
                      ],
                    );
        },
      ),
    );
  }
}

class ImageItem<T extends Object> with ChangeNotifier {
  Widget fallBackWidget;
  ImageData? image;
  Object tag;
  bool hidden = false;

  void markCorrupt() {
    if (hidden) return;
    hidden = true;
    notifyListeners();
  }

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
      if (value != null) {
        hidden = false;
        this.tag = value.id;
      } else {
        hidden = true;
      }
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
      if (value != null) {
        hidden = false;
        this.tag = value.id;
      } else {
        hidden = true;
        this.fallBackWidget = Center(child: const Icon(Icons.report_problem));
      }
      // debugPrint(this.tag.toString());
      notifyListeners();
    });
  }
}
