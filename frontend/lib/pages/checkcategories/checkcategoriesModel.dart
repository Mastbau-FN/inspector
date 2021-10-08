import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/fragments/imageWrap.dart';
import 'package:mastbau_inspector/pages/checkpoints/checkpointsModel.dart';
import 'package:mastbau_inspector/pages/checkpoints/checkpointsView.dart';
import 'package:provider/provider.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

import '../imageView.dart';

class CategoryModel extends DropDownModel<CheckCategory> {
  final Backend _b = Backend();
  final InspectionLocation currentLocation;

  static const _nextViewTitle = "Prüfpunkte";

  CategoryModel(this.currentLocation);

  Future<List<CheckCategory>> get all async =>
      _b.getAllCheckCategoriesForLocation(currentLocation);

  @override
  List<MyListTileData> actions = [
    MyListTileData(title: _nextViewTitle),
    MyListTileData(title: "Fotos"),
    MyListTileData(title: "Kommentar"),
  ];

  @override
  String get title => '$currentLocation';

  @override
  void open(
    BuildContext context,
    CheckCategory data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return ChangeNotifierProvider<CheckPointsModel>(
              create: (c) => CheckPointsModel(data),
              child: CheckPointsView(),
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
