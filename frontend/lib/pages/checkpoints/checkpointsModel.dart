import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/fragments/imageWrap.dart';
import 'package:mastbau_inspector/pages/checkpointdefects/checkpointdefectsModel.dart';
import 'package:mastbau_inspector/pages/checkpointdefects/checkpointdefectsView.dart';
import 'package:provider/provider.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

import '../imageView.dart';

class CheckPointsModel extends DropDownModel<CheckPoint> with ChangeNotifier {
  final Backend _b = Backend();
  final CheckCategory currentCategory;

  static const _nextViewTitle = "Prüfpunkte";

  CheckPointsModel(this.currentCategory);

  Future<List<CheckPoint>> get all async =>
      _b.getAllCheckPointsForCategory(currentCategory);

  @override
  List<MyListTileData> actions = [
    MyListTileData(title: _nextViewTitle),
    MyListTileData(title: "Fotos"),
    MyListTileData(title: "Kommentar"),
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
            return ChangeNotifierProvider<CheckPointDefectsModel>(
              create: (c) => CheckPointDefectsModel(data),
              child: CheckPointDefectsView(),
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
