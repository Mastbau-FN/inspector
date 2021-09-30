import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/data/checkpointdefect.dart';
import 'package:mastbau_inspector/classes/data/checkpoint.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

class CheckPointDefectsModel extends DropDownModel<CheckPointDefect>
    with ChangeNotifier {
  final Backend _b = Backend();
  final CheckPoint currentCheckPoint;

  static const _nextViewTitle = "Prüfpunkte";

  CheckPointDefectsModel(this.currentCheckPoint);

  Future<List<CheckPointDefect>> get all async =>
      _b.getAllDefectsForCheckpoint(currentCheckPoint);

  @override
  List<MyListTileData> actions = [
    MyListTileData(title: "Details"),
    MyListTileData(title: "Fotos"),
  ];

  @override
  String get title => currentCheckPoint.title;

  @override
  void open(
    BuildContext context,
    CheckPointDefect data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (newcontext) => Text("TODO"),
      ),
    );
  }
}
