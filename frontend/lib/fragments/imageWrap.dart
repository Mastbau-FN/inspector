import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:flutter/material.dart';

class ImageWrap extends StatelessWidget {
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
  Widget build(BuildContext context) => GridView.builder(
      padding: const EdgeInsets.all(2.0),
      itemCount: images.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount),
      itemBuilder: (context, i) => (i == 0)
          ? ImageView(
              img: chosenOne,
              isChosen: true,
            )
          : (i >= images.length)
              ? Container()
              : Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: FutureBuilder(
                      future: images[i],
                      builder: (BuildContext context,
                              AsyncSnapshot<Image?> snap) =>
                          (snap.connectionState == ConnectionState.done)
                              ? ImageView(img: snap.data)
                              : Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: LoadingView(),
                                ) //hm this gets also triggered if the snapshot completed, but no image could be parsed

                      ),
                ));
}

class ImageView extends StatelessWidget {
  final Image? img;
  final bool isChosen;
  const ImageView({
    required this.img,
    Key? key,
    this.isChosen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          _heroImg(context),
          if (isChosen)
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
    if (img == null) return Center(child: Icon(Icons.report_problem));
    var tag = key ?? UniqueKey();
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
      ),
      child: Hero(
        tag: tag,
        child: FittedImageContainer(
          img: img!,
        ),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (c) => FullImagePage(
                  tag: tag,
                  img: img!,
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
        appBar: AppBar(title: Text("Bild")), body: Hero(child: img, tag: tag));
  }
}
