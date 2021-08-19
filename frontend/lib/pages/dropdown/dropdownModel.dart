import 'package:flutter/material.dart';
import 'package:mastbau_inspector/classes/listTileData.dart';

abstract class Data {
  String get title;
}

abstract class DropDownModel<DataT extends Data> {
  String get title;
  Future<List<DataT>> get all;

  List<MyListTileData> get actions;

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
