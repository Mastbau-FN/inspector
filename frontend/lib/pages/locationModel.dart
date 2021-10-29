import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inspector/backend/api.dart';
import 'package:inspector/classes/data/inspection_location.dart';
import 'package:inspector/classes/listTileData.dart';
import 'package:inspector/classes/user.dart';
import 'package:inspector/pages/checkcategoriesModel.dart';
import 'package:inspector/pages/dropdown/dropdownModel.dart';

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
            return ImageView(
              images: data.images,
              onNewImages: (files) => Backend().uploadFiles(data, files),
            );
          default:
            return DetailsPage(
                title: data.title,
                details: data.toJson().toString(),
                onChanged: (txt) {/*TODO*/});
        }
      }),
    );
  }
}
