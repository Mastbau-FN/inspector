import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';

import 'galleryWrapper.dart';

class ImageWrap<T extends Object> extends StatelessWidget {
  static final _fetchallfirst = false;

  static _default(Object _) {
    Fluttertoast.showToast(
      msg: "Not Available",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
  }

  final Function(T) onDelete;
  final Function(T) onStar;
  final Function(T) onShare;

  final ImageData<T>? chosenOne;
  final List<Future<ImageData<T>?>> images;
  final int columnCount;
  ImageWrap.constant({
    List<ImageData<T>> images = const [],
    this.columnCount = 4,
    Key? key,
    this.chosenOne,
    this.onDelete = _default,
    this.onStar = _default,
    this.onShare = _default,
  })  : this.images = images.map((e) => Future.value(e)).toList(),
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
            images.map((e) => ImageItem.fromFutureImageData(e)).toList(),
        super(key: key);

  final List<ImageItem<T>> _allImages;

  //TODO; chose new mainImage -> callback
  @override
  Widget build(BuildContext context) => FutureBuilder<List<ImageItem<T>>>(
        future: !_fetchallfirst
            ? null
            : Future.wait(images).then((e) =>
                e.map((image) => ImageItem.fromImageData(image)).toList()),
        builder: (context, snapshot) {
          if (_fetchallfirst &&
              snapshot.connectionState != ConnectionState.done)
            return LoadingView();
          return GridView.builder(
              padding: const EdgeInsets.all(2.0),
              itemCount:
                  !_fetchallfirst ? images.length : snapshot.data?.length ?? 0,
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
                        0, //TODO: make this dynamic on callback or something for #20
                    allImages:
                        !_fetchallfirst ? _allImages : snapshot.data ?? [],
                  ));
        },
      );
}

class OpenableImageView<T extends Object> extends StatelessWidget {
  static _default(_) {
    Fluttertoast.showToast(
      msg: "Not Available",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
    );
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
    return Container(
      child: Stack(
        children: [
          _heroImg(context),
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
  }

  Widget _heroImg(context) {
    Object tag = allImages[currentIndex].tag;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
      ),
      child: Hero(
        tag: tag,
        child: FittedImageContainer(
          img: allImages[currentIndex],
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
        onDelete(tag);
        break;
      case ImageOptions.setMain:
        onStar(tag);
        break;
      case ImageOptions.share:
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
        Navigator.pop(context, ImageOptions.setMain);
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
