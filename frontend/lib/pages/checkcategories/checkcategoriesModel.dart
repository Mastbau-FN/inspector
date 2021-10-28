import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inspector/backend/api.dart';
import 'package:inspector/classes/data/checkcategory.dart';
import 'package:inspector/classes/data/inspection_location.dart';
import 'package:inspector/classes/listTileData.dart';
import 'package:inspector/fragments/imageWrap.dart';
import 'package:inspector/pages/checkpoints/checkpointsModel.dart';
import 'package:inspector/pages/checkpoints/checkpointsView.dart';
import 'package:provider/provider.dart';
import 'package:inspector/pages/dropdown/dropdownModel.dart';

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
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.checklist,
    ),
    MyListTileData(
      title: "Fotos",
      icon: Icons.photo_library,
    ),
    MyListTileData(
      title: "Kommentar",
      icon: Icons.text_snippet,
    ),
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

  @override
  Widget? get floatingActionButton => FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: "neuen Kategorie hinzufügen",
        onPressed: () {},
      );
}
