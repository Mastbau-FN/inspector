import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter/scheduler.dart';

import 'loadingscreen/loadingView.dart';

@visibleForTesting
int galleryDecodeExtent(
  MediaQueryData mediaQuery, {
  required bool isCurrent,
}) {
  final physicalLongestSide =
      mediaQuery.size.longestSide * mediaQuery.devicePixelRatio;
  if (isCurrent) {
    // The active page must retain enough detail for PhotoView zoom. Only this
    // page may use a 4K decode; adjacent pages remain lightweight below.
    return (physicalLongestSide * 1.5).ceil().clamp(2048, 4096).toInt();
  }
  return (physicalLongestSide * 0.6).ceil().clamp(768, 1920).toInt();
}

/// Drops decoded inspection photos after an image-heavy route has left the
/// screen. Navigator keeps previous routes mounted, so relying only on the
/// global LRU cache otherwise retains gallery bitmaps throughout a field day.
void releaseInspectionImageCacheAfterFrame() {
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.clear();
  imageCache.clearLiveImages();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    imageCache.clear();
    imageCache.clearLiveImages();
  });
}

class GalleryPhotoViewWrapper extends StatefulWidget {
  GalleryPhotoViewWrapper({
    this.loadingBuilder,
    this.backgroundDecoration,
    this.minScale,
    this.maxScale,
    this.initialIndex = 0,
    required this.galleryItems,
    this.scrollDirection = Axis.horizontal,
    this.onRotate,
  }) : pageController = PageController(initialPage: initialIndex);

  final LoadingBuilder? loadingBuilder;
  final BoxDecoration? backgroundDecoration;
  final dynamic minScale;
  final dynamic maxScale;
  final int initialIndex;
  final PageController pageController;
  final List<ImageItem> galleryItems;
  final Axis scrollDirection;
  final FutureOr<void> Function(Object id, int deltaQuarterTurns)? onRotate;

  @override
  State<StatefulWidget> createState() {
    return _GalleryPhotoViewWrapperState();
  }
}

class _GalleryPhotoViewWrapperState extends State<GalleryPhotoViewWrapper> {
  late int currentIndex = widget.initialIndex;
  final Map<Object, int> _quarterTurnsByTag = <Object, int>{};

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  void dispose() {
    widget.pageController.dispose();
    releaseInspectionImageCacheAfterFrame();
    super.dispose();
  }

  Future<void> _rotateCurrent(int deltaQuarterTurns) async {
    if (widget.galleryItems.isEmpty) return;
    final currentTag = widget.galleryItems[currentIndex].tag;
    final current = _quarterTurnsByTag[currentTag] ?? 0;
    final next = (current + deltaQuarterTurns) % 4;
    final normalized = (next + 4) % 4;
    setState(() {
      if (normalized == 0) {
        _quarterTurnsByTag.remove(currentTag);
      } else {
        _quarterTurnsByTag[currentTag] = normalized;
      }
    });

    final id = widget.galleryItems[currentIndex].image?.id;
    if (id != null && widget.onRotate != null) {
      await Future.sync(() => widget.onRotate!(id, deltaQuarterTurns));
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentName() {
      final explicit = widget.galleryItems[currentIndex].image?.name;
      if (explicit != null && explicit.trim().isNotEmpty)
        return explicit.trim();
      final id = widget.galleryItems[currentIndex].image?.id.toString();
      if (id == null || id.isEmpty) return '';
      final parts = id.split('/').where((e) => e.isNotEmpty).toList();
      return parts.isEmpty ? id : parts.last;
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Nach links drehen',
            icon: const Icon(Icons.rotate_left),
            onPressed: () async => _rotateCurrent(-1),
          ),
          IconButton(
            tooltip: 'Nach rechts drehen',
            icon: const Icon(Icons.rotate_right),
            onPressed: () async => _rotateCurrent(1),
          ),
        ],
      ),
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
      child: FullImg(
        item: item,
        isCurrent: index == currentIndex,
        quarterTurns: _quarterTurnsByTag[item.tag] ?? 0,
      ),
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
  final bool isCurrent;
  final int quarterTurns;
  const FullImg({
    super.key,
    required this.item,
    this.isCurrent = true,
    this.quarterTurns = 0,
  });

  Widget _safe(BuildContext context, Image img) {
    final mediaQuery = MediaQuery.of(context);
    final decodeExtent = galleryDecodeExtent(
      mediaQuery,
      isCurrent: isCurrent,
    );
    final image = Image(
      // A 40-50 MP photo needs roughly 160-200 MB once decoded. Decode only the
      // current page at zoom quality and keep PhotoView's adjacent pages small.
      image: ResizeImage.resizeIfNeeded(
        decodeExtent,
        decodeExtent,
        img.image,
      ),
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
    if (quarterTurns == 0) return image;
    return RotatedBox(quarterTurns: quarterTurns, child: image);
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
              ? _safe(context, snapshot.data!)
              : (item.image?.image != null)
                  ? _safe(context, item.image!.image)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        if (item.image != null)
                          _safe(context, item.image!.image),
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
  StreamSubscription<ImageData<T>?>? _subscription;

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
    _subscription = image.listen((value) {
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
    }, onError: (_) {
      hidden = true;
      this.fallBackWidget = Center(child: const Icon(Icons.report_problem));
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
