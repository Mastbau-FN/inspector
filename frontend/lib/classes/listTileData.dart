import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import 'package:mastbau_inspector/widgets/MyListTile1.dart';

/// a struct for bundling stuff needed to inflate a [MyCardListTile1] which then opens the widget given by [nextBuilder]
class MyListTileData {
  final String title;
  final IconData? icon;
  final BuilderT nextBuilder;

  const MyListTileData(
      {required this.title, this.icon, required this.nextBuilder});
}
