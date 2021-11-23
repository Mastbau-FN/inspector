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
              : FutureBuilder(
                  future: images[i],
                  builder: (BuildContext context, AsyncSnapshot<Image?> snap) =>
                      (snap.connectionState == ConnectionState.done)
                          ? ImageView(img: snap.data)
                          : Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: LoadingView(),
                            ) //hm this gets also triggered if the snapshot completed, but no image could be parsed

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
          img ?? Center(child: Icon(Icons.report_problem)),
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
}
