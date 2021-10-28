import 'package:flutter/material.dart';

class MyCardListTile1 extends StatelessWidget {
  IconData icon;
  String text;
  void Function()? onTap;

  MyCardListTile1({
    IconData? icon,
    this.text = "Click mich doch",
    this.onTap,
  }) : this.icon = icon ?? Icons.apps;

  @override
  Widget build(BuildContext context) {
    final makeListTile = ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
        leading: Icon(icon, color: Colors.amber[400]),
        title: Text(
          text,
          //style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        trailing:
            Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 30.0));

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      elevation: 8.0,
      margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: makeListTile,
    );
  }
}
