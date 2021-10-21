//TODO: nextView()/DropDownPage braucht noch ein child oÄ womit dann das hinzufügen zb ermöglicht wird (oder ein add-callback-parameter der wieder generic für alle aktiviert werden kann im model hinterlegt)

import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/checkpointdefect.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/pages/checkpointdefects/checkpointdefectsModel.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';
import 'package:mastbau_inspector/pages/locationOverview/locationModel.dart';
import 'package:provider/provider.dart';

abstract class WithImgHashes {
  List<String>? imagehashes = []; //should not be used
  List<Image?>? images = [];
}

/// interface that all our models need to use to handle data like e.g. [InspectionLocation]
abstract class Data implements WithImgHashes {
  String get title;

  /// an optional extra Widget, to display extra data (currently only used by [CheckPointDefect] to show the urgency)
  Widget? get extra => null;

  Map<String, dynamic> toJson();
  Map<String, dynamic> toSmallJson();

  // sadly https://github.com/dart-lang/language/issues/356
  static T? fromJson<T extends Data>(Map<String, dynamic> map) => null;
}

/// this class must be implemented by all models for the main pages like e.g. [LocationModel]
abstract class DropDownModel<DataT extends Data> with ChangeNotifier {
  /// could be used for the scaffold appbar title
  String get title;

  /// returns a [List] of all the [Data] for this Model
  Future<List<DataT>> get all;

  /// a [List] which all the actions that could be made for a specific DropDown
  List<MyListTileData> get actions;

  /// when pressed on a tile in the [DropDownPage] this will be invoked
  void open(
    BuildContext context,
    DataT data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (newcontext) => Text("${tiledata.title} not yet implemeted"),
    ));
  }
}

//TODO alternativ schonmal bissl issue #14:
Widget nextModel<DDModel extends DropDownModel>(DDModel child) =>
    ChangeNotifierProvider<DDModel>(
      create: (c) => child,
      child: DropDownPage<DDModel>(),
    );

Type typeOf<T>() => T;
typedef BuilderT = Widget Function(BuildContext);
