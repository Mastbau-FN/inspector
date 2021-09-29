import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/data/inspection_location.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownPage.dart';
import 'package:mastbau_inspector/pages/locationOverview/locationModel.dart';

abstract class WithImgHashes {
  List<String>? imagehashes = []; //should not be used
  List<Image?>? images = [];
}

/// interface that all our models need to use to handle data like e.g. [InspectionLocation]
abstract class Data implements WithImgHashes {
  String get title;

  Map<String, dynamic> toJson();
  Map<String, dynamic> toSmallJson();

  // sadly https://github.com/dart-lang/language/issues/356
  static T? fromJson<T extends Data>(Map<String, dynamic> map) => null;
}

/// this class must be implemented by all models for the main pages like e.g. [LocationModel]
abstract class DropDownModel<DataT extends Data> {
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
      builder: (newcontext) => tiledata.nextBuilder(newcontext),
    ));
  }
}

Type typeOf<T>() => T;
typedef BuilderT = Widget Function(BuildContext);
