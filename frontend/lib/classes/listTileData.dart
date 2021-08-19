import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

class MyListTileData {
  final String title;
  final IconData? icon;
  final BuilderT nextBuilder;

  const MyListTileData(
      {required this.title, this.icon, required this.nextBuilder});
}
