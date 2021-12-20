import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import 'gallaryWrapper.dart';

class ImageWrap extends StatelessWidget {
  static final _fetchallfirst = true; //TODO: this shall be false at some point

  final Image? chosenOne;
  final List<Future<Image?>> images;
  final int columnCount;
  ImageWrap.constant({
    List<Image> images = const [],
    this.columnCount = 4,
    Key? key,
    this.chosenOne,
  })  : this.images = images.map((e) => Future.value(e)).toList(),
        super(key: key);
  ImageWrap.futured({
    required this.images,
    this.columnCount = 4,
    Key? key,
    this.chosenOne,
  }) : super(key: key);

  //TODO; chose new mainImage -> callback
  @override
  Widget build(BuildContext context) => FutureBuilder<List<ImageItem>>(
        future: Future.wait(images).then((e) => e
            .map((image) => ImageItem.fromImage(image, tag: UniqueKey()))
            .toList()),
        builder: (context, snapshot) {
          return GridView.builder(
              padding: const EdgeInsets.all(2.0),
              itemCount: images.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
              ),
              itemBuilder: (context, i) => /*(i == 0)
              ? */
                  OpenableImageView.scrollable(
                    currentIndex: i,
                    chosenIndex:
                        0, //TODO: make this dynamic on callback or something for #20
                    allImages: snapshot.data ?? [],
                  ));
        },
      );
}

class OpenableImageView extends StatelessWidget {
  ///which index has the main image ; -1 means none is chosen
  final int chosenIndex;

  ///the index of the image that shall be opened
  final int currentIndex;

  ///an optional List of all images on which we can scroll to
  final List<ImageItem> allImages;

  ///whether one can slide from one opened widget to another one
  final bool _isScrollable;
  const OpenableImageView.scrollable({
    //which item from this list shall be opened
    required this.currentIndex,
    required this.allImages,
    Key? key,
    this.chosenIndex = -1,
  })  : assert(0 <= currentIndex && currentIndex <= (allImages.length)),
        this._isScrollable = (allImages != null),
        super(key: key);

  /*const*/ OpenableImageView.only({
    //which item from this list shall be opened
    required ImageItem image,
    Key? key,
    bool isChosen = false,
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
    ImageProvider? img = allImages[currentIndex].image;
    if (img == null) return Center(child: Icon(Icons.report_problem));
    var tag = allImages[currentIndex].tag;
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
      ),
      child: Hero(
        tag: tag,
        child: FittedImageContainer(
          img: Image(
            image: img,
          ),
        ),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (c) => _isScrollable
                ? GalleryPhotoViewWrapper(
                    galleryItems: allImages,
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.black,
                    ),
                    initialIndex: currentIndex,
                    scrollDirection: Axis.vertical,
                  )
                : FullImagePage(
                    tag: tag,
                    img: Image(
                      image: img,
                    ),
                  )),
      ),
    );
  }
}

//TODO: also make it possible to delete/set-as-main image (#36)
class FittedImageContainer extends StatelessWidget {
  const FittedImageContainer({
    Key? key,
    required this.img,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  final Image img;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: img
              .image, //XXX: have a list of imageproviders instead of image widgets
          fit: fit,
        ),
      ),
    );
  }
}

class FullImagePage extends StatelessWidget {
  const FullImagePage({
    required this.img,
    required this.tag,
    Key? key,
  }) : super(key: key);

  final Image img;
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
