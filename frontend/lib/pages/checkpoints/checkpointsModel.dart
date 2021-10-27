import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/pages/checkpointdefects/checkpointdefectsModel.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

import '../imageView.dart';

class CheckPointsModel extends DropDownModel<CheckPoint> {
  final Backend _b = Backend();
  final CheckCategory currentCategory;

  static const _nextViewTitle = "Defekte";

  CheckPointsModel(this.currentCategory);

  Future<List<CheckPoint>> get all async =>
      _b.getAllCheckPointsForCategory(currentCategory);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.report_problem,
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
  String get title => currentCategory.title;

  @override
  void open(
    BuildContext context,
    CheckPoint data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel(CheckPointDefectsModel(data));
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
