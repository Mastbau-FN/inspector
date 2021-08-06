import 'package:flutter/material.dart';
import 'package:mastbau_inspector/widgets/MyListTile1.dart';
import 'package:mastbau_inspector/fragments/RandomDogsScrollView.dart';

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            child: Center(
                child: Text(
              'Mastbau FN',
              style: TextStyle(
                  fontSize: 32, color: Theme.of(context).backgroundColor),
            )),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).accentColor
              ]),
              //color: Theme.of(context).primaryColor,
            ),
          ),
          MyCardListTile1(
            icon: Icons.child_care,
            text: 'Unendlich Hunde',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RandomDogsScrollView()),
              );
            },
          ),
        ],
      ),
    );
  }
}
