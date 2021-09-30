import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/classes/user.dart';
import 'package:mastbau_inspector/pages/checkcategories/checkcategoriesModel.dart';
import 'package:mastbau_inspector/pages/checkcategories/checkcategoriesView.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import 'package:provider/provider.dart';

import '../imageView.dart';

class LocationModel extends DropDownModel<InspectionLocation>
    with ChangeNotifier {
  final Backend _b = Backend();
  final DisplayUser? user;

  static const _nextViewTitle = "Prüfkategorien";

  LocationModel({this.user});

  Future<List<InspectionLocation>> get all async =>
      _b.getAllInspectionLocationsForCurrentUser();

  @override
  final List<MyListTileData> actions = [
    MyListTileData(title: _nextViewTitle),
    MyListTileData(title: "Fotos"),
    MyListTileData(title: "Infos"),
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
            return ChangeNotifierProvider<CategoryModel>(
              create: (c) => CategoryModel(data),
              child: CategoriesView(),
            );
          case 'Fotos':
            return ImageView(
              images: data.images,
            );

          default:
            return Text("TODO");
        }
      }),
    );
  }
}
