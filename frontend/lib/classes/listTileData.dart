import 'package:flutter/material.dart';

class MyListTileData {
  final String title;
  final IconData? icon;
  final Widget Function(BuildContext) nextBuilder;

  const MyListTileData(
      {required this.title, this.icon, required this.nextBuilder});
}
