import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownModel.dart';

import 'imageView.dart';
import 'detailsPage.dart';

class LocationModel extends DropDownModel<InspectionLocation> {
  final Backend _b = Backend();
  final DisplayUser? user;

  static const _nextViewTitle = "Prüfkategorien";

  LocationModel({this.user});

  Future<List<InspectionLocation>> get all async =>
      _b.getAllInspectionLocationsForCurrentUser();

  @override
  final List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.category,
    ),
    MyListTileData(
      title: "Fotos",
      icon: Icons.photo_library,
    ),

    ///see #24
    MyListTileData(
      title: "Infos",
      icon: Icons.text_snippet,
    ),
  ];

  @override
  String get title => 'Inspektionen: $user';

  @override
  void open(
    BuildContext context,
    InspectionLocation data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel(CategoryModel(data));
          case 'Fotos':
            return ImageView.futured(
              future_images: data.image_futures,
              onNewImages: (files) => Backend().uploadFiles(data, files),
            );
          default:
            return LocationDetailPage(
              locationdata: data,
            );
        }
      }),
    );
  }
}

class LocationDetailPage extends StatelessWidget {
  final InspectionLocation locationdata;
  const LocationDetailPage({required this.locationdata, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: Text(locationdata.title),
      ),
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _previewImg(),
            _mgauftr(),
            _standort(),
          ],
        ),
      ));

  ClipOval _previewImg() => ClipOval(
        child: Container(
          height: 50,
          width: 50,
          child: FutureBuilder<Image?>(
              future: locationdata.mainImage,
              builder: (context, snapshot) =>
                  snapshot.data ?? Icon(Icons.construction)),
        ),
      );

  Widget _mgauftr() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("${locationdata.pjNr}, ${locationdata.bauleitung}"),
          Text("${locationdata.pjName}"),
          Text("${locationdata.pjInfo}"),
        ],
      );

  Widget _standort() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("${locationdata.stONr}:"),
          Text("${locationdata.strasse}"),
          Text("${locationdata.plz}, ${locationdata.ort}"),
        ],
      );
}
