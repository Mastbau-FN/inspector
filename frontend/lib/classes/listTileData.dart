import 'package:flutter/material.dart';
import 'package:inspector/pages/dropdown/dropdownModel.dart';
import 'package:inspector/widgets/MyListTile1.dart';

/// a struct for bundling stuff needed to inflate a [MyCardListTile1] which then opens the widget given by [nextBuilder]
class MyListTileData {
  final String title;
  final IconData? icon;

  const MyListTileData({required this.title, this.icon});
}
