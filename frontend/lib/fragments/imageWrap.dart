import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/material.dart';

import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

import 'galleryWrapper.dart';

class ImageWrap<T extends Object> extends StatelessWidget {
  static _default(Object _) {
    showToast("Not Available");
  }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  final ImageData<T>? chosenOne;
  final List<Stream<ImageData<T>?>> images;
  final int columnCount;
  ImageWrap.constant({
    List<ImageData<T>> images = const [],
    this.columnCount = 4,
    Key? key,
    this.chosenOne,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : this.images = images.map((e) => Stream.value(e)).toList(),
        _allImages = images.map((e) => ImageItem.fromImageData(e)).toList(),
        super(key: key);

  ImageWrap.futured({
    required this.images,
    this.columnCount = 4,
    Key? key,
    this.chosenOne,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : _allImages =
            images.map((e) => ImageItem.fromImageDataStream(e)).toList(),
        super(key: key);

  ImageWrap.streamed({
    required this.images,
    this.columnCount = 4,
    Key? key,
    this.chosenOne,
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
                    chosenIndex:
                        0, //// make this dynamic on callback or something for #20
                    // instead solve #36 and move chosen image to front
                    allImages: _allImages,
                  ));
        },
      );
}

class OpenableImageView<T extends Object> extends StatelessWidget {
  static _default(_) {
    showToast("Not Available");
  }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  ///which index has the main image ; -1 means none is chosen
  final int chosenIndex;

  ///the index of the image that shall be opened
  final int currentIndex;

  ///an optional List of all images on which we can scroll to
  final List<ImageItem<T>> allImages;

  ///whether one can slide from one opened widget to another one
  final bool _isScrollable;
  const OpenableImageView.scrollable({
    //which item from this list shall be opened
    required this.currentIndex,
    required this.allImages,
    Key? key,
    this.chosenIndex = -1,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : assert(0 <= currentIndex && currentIndex < (allImages.length)),
        this._isScrollable = true,
        super(key: key);

  /*const*/ OpenableImageView.only({
    //which item from this list shall be opened
    required ImageItem<T> image,
    Key? key,
    bool isChosen = false,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : this._isScrollable = false,
        this.currentIndex = 0,
        this.chosenIndex = isChosen ? 0 : -1,
        this.allImages = [image], //todo: make this literal const?
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
                    //todo: maybe ad shadow or border to better see it
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
        ),
      ),
      onLongPress: () => _onLongPress(context, tag),
      onPressed: () => _onShortPress(context, tag),
    );
  }

  void _onShortPress(context, tag) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (c) => _isScrollable
                ? GalleryPhotoViewWrapper(
                    galleryItems: allImages,
                    backgroundDecoration:
                        BoxDecoration(color: Theme.of(context).canvasColor),
                    initialIndex: currentIndex,
                    scrollDirection: Axis.horizontal,
                  )
                : FullImagePage(
                    tag: tag,
                    img: allImages[currentIndex],
                  )),
      );

  Future<void> _onLongPress(context, tag) async {
    switch (await showDialog<ImageOptions>(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text('Bild-Optionen:'),
            children: <Widget>[
              _option(
                context: context,
                description: 'Bild dauerhaft entfernen',
                icon: Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
                returnCase: ImageOptions.delete,
              ),
              _option(
                context: context,
                description: 'Bild als Vorschaubild setzen',
                icon: Icon(
                  Icons.star,
                  color: Colors.amber[300],
                ),
                returnCase: ImageOptions.setMain,
              ),
              _option(
                context: context,
                description: 'Bild teilen',
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

//TODO: also make it possible to delete/set-as-main image (#36)
class FittedImageContainer extends StatelessWidget {
  const FittedImageContainer({
    Key? key,
    required this.img,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  final ImageItem img;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: img,
      child: Consumer<ImageItem>(builder: (_, img, __) {
        return Container(
          child: img.image != null ? null : img.fallBackWidget,
          decoration: img.image == null
              ? null
              : BoxDecoration(
                  image: DecorationImage(
                    image: img
                        .image!, //XXX: have a list of imageproviders instead of image widgets
                    fit: fit,
                  ),
                ),
        );
      }),
    );
  }
}

class FullImagePage extends StatelessWidget {
  const FullImagePage({
    required this.img,
    required this.tag,
    Key? key,
  }) : super(key: key);

  final ImageItem img;
  final Object tag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bild")),
      body: Hero(
        child: PhotoView(
          imageProvider: img.image,
          backgroundDecoration:
              BoxDecoration(color: Theme.of(context).canvasColor),
        ),
        tag: tag,
      ),
    );
  }
}
