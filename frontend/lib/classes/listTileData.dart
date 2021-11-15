import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownModel.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';

/// a struct for bundling stuff needed to inflate a [MyCardListTile1] which then opens the widget given by [nextBuilder]
class MyListTileData {
  final String title;
  final IconData? icon;

  const MyListTileData({required this.title, this.icon});
}
