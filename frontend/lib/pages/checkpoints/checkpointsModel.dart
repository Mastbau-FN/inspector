import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/checkcategory.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/pages/checkpointdefects/checkpointdefectsModel.dart';
import 'package:provider/provider.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

class CheckPointsModel extends DropDownModel<CheckPoint> with ChangeNotifier {
  final Backend _b = Backend();
  final CheckCategory currentCategory;

  static const _nextViewTitle = "Prüfpunkte";

  CheckPointsModel(this.currentCategory);

  Future<List<CheckPoint>> get all async =>
      _b.getAllCheckPointsForCategory(currentCategory);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      nextBuilder: (c) => Text('todo'), //TODO
    ),
    MyListTileData(
      title: "Fotos",
      nextBuilder: (c) => Text('todo'), //TODO
    ),
    MyListTileData(
      title: "Kommentar",
      nextBuilder: (c) => Text('todo'), //TODO
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
      MaterialPageRoute(
        builder: (newcontext) => tiledata.title == _nextViewTitle
            ? ChangeNotifierProvider<CheckPointDefectsModel>(
                create: (c) => CheckPointDefectsModel(
                    data), //TODO swap with model for next view
                child: tiledata.nextBuilder(newcontext),
              )
            : tiledata.nextBuilder(newcontext),
      ),
    );
  }
}
