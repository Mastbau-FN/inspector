import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'galleryWrapper.dart';

class ImageWrap<T extends Object> extends StatelessWidget {
  static _default(Object _) {
    showToast(S.current!.notAvailable);
  }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  final bool? hasFav;
  final List<Stream<ImageData<T>?>> images;
  final int columnCount;
  ImageWrap.constant({
    List<ImageData<T>> images = const [],
    this.columnCount = 4,
    Key? key,
    this.hasFav,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : this.images = images.map((e) => Stream.value(e)).toList(),
        _allImages = images.map((e) => ImageItem.fromImageData(e)).toList(),
        super(key: key);

  ImageWrap.futured({
    required List<Future<ImageData<T>?>> images,
    this.columnCount = 4,
    Key? key,
    this.hasFav,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : this.images = images.map((e) => Stream.fromFuture(e)).toList(),
        _allImages =
            images.map((e) => ImageItem.fromFutureImageData(e)).toList(),
        super(key: key);

  ImageWrap.streamed({
    required this.images,
    this.columnCount = 4,
    Key? key,
    this.hasFav,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : _allImages =
            images.map((e) => ImageItem.fromImageDataStream(e)).toList(),
        super(key: key);

  final List<ImageItem<T>> _allImages;

  @override
  Widget build(BuildContext context) => Builder(
        builder: (context) {
          return GridView.builder(
              padding: const EdgeInsets.all(2.0),
              itemCount: images.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
              ),
              itemBuilder: (context, i) => /*(i == 0)
              ? */
                  OpenableImageView<T>.scrollable(
                    onDelete: onDelete,
                    onShare: onShare,
                    onStar: onStar,
                    currentIndex: i,
                    chosenIndex: (hasFav ?? true)
                        ? 0
                        : -1, //// make this dynamic on callback or something for #20
                    // instead solve #36 and move chosen image to front
                    allImages: _allImages,
                    approxWidth:
                        MediaQuery.of(context).size.width / columnCount,
                  ));
        },
      );
}

class OpenableImageView<T extends Object> extends StatelessWidget {
  static _default(_) {
    showToast(S.current!.notAvailable);
  }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  ///expected width of thumbnail to determine resolution
  final num approxWidth;

  ///which index has the main image ; -1 means none is chosen
  final int chosenIndex;

  ///the index of the image that shall be opened
  final int currentIndex;

  ///an optional List of all images on which we can scroll to
  final List<ImageItem<T>> allImages;

  const OpenableImageView.scrollable({
    //which item from this list shall be opened
    required this.currentIndex,
    required this.allImages,
    Key? key,
    this.chosenIndex = -1,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
    required this.approxWidth,
  })  : assert(0 <= currentIndex && currentIndex < (allImages.length)),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: allImages[currentIndex],
      child: Builder(builder: (context) {
        return Container(
          child: Stack(
            children: [
              Consumer<ImageItem>(builder: (context, imgModel, _) {
                return _heroImg(context, imgModel);
              }),
              if (chosenIndex == currentIndex)
                Positioned(
                  child: Icon(
                    //todo: maybe add shadow or border to better see it
                    Icons.star,
                    color: Colors.amber,
                  ),
                  left: 8,
                  top: 8,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _heroImg(context, img) {
    Object tag = img.tag;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
      ),
      child: Hero(
        tag: tag,
        child: FittedImageContainer(
          img: img,
          approxWidth: approxWidth,
        ),
      ),
      onLongPress: () => _onLongPress(context, tag),
      onPressed: () => _onShortPress(context, tag),
    );
  }

  void _onShortPress(context, tag) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => GalleryPhotoViewWrapper(
            galleryItems: allImages,
            backgroundDecoration:
                BoxDecoration(color: Theme.of(context).canvasColor),
            initialIndex: currentIndex,
            scrollDirection: Axis.horizontal,
          ),
        ),
      );

  Future<void> _onLongPress(context, tag) async {
    switch (await showDialog<ImageOptions>(
        barrierColor: Colors.black54,
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Text(S.of(context).optionsForThisImageHeadLine),
            children: <Widget>[
              _option(
                context: context,
                description: S.of(context).permanentlyRemoveImage,
                icon: Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                returnCase: ImageOptions.delete,
              ),
              _option(
                context: context,
                description: S.of(context).setAsMainImage,
                icon: Icon(
                  Icons.star,
                  color: Colors.amber[300],
                ),
                returnCase: ImageOptions.setMain,
              ),
              _option(
                context: context,
                description: S.of(context).shareImage,
                icon: Icon(
                  Icons.share,
                  color: Colors.blue,
                ),
                returnCase: ImageOptions.share,
              ),
            ],
          );
        })) {
      case ImageOptions.delete:
        debugPrint("image Deleted");
        debugPrint(tag);
        onDelete(tag);
        break;
      case ImageOptions.setMain:
        debugPrint("image set to be main");
        onStar(tag);
        break;
      case ImageOptions.share:
        debugPrint("image shared");
        onShare(tag);
        break;
      case null:
        // dialog dismissed
        break;
    }
  }

//could be extracted into an standalone widget..
  SimpleDialogOption _option(
      {required BuildContext context,
      Icon icon = const Icon(Icons.circle),
      required String description,
      ImageOptions? returnCase}) {
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, returnCase);
      },
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(description),
            icon,
          ],
        ),
      ),
    );
  }
}

enum ImageOptions {
  delete,
  setMain,
  share,
  //XXX: mehr?
}

class FittedImageContainer extends StatelessWidget {
  const FittedImageContainer({
    Key? key,
    required this.img,
    this.fit = BoxFit.cover,
    required this.approxWidth,
  }) : super(key: key);

  final ImageItem img;
  final BoxFit fit;
  final num approxWidth;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: img,
      child: Consumer<ImageItem>(builder: (_, img, __) {
        return FutureBuilder<Image?>(
            future: (img.image == null)
                ? null
                : ((approxWidth > 100)
                    ? img.image!.fullImage()
                    : Future.value(img.image!.thumbnail)),
            builder: (context, snapshot) {
              return Container(
                child: img.image != null ? null : img.fallBackWidget,
                decoration: snapshot.data?.image == null
                    ? null
                    : BoxDecoration(
                        image: DecorationImage(
                          image: snapshot.data!.image,
                          fit: fit,
                        ),
                      ),
              );
            });
      }),
    );
  }
}
