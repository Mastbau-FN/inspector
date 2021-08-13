import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/login/loginModel.dart';
import 'package:mastbau_inspector/pages/settings/settingsView.dart';
import 'package:mastbau_inspector/widgets/MyListTile1.dart';
import 'package:mastbau_inspector/fragments/RandomDogsScrollView.dart';
import 'package:provider/provider.dart';

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var unlimiteddoggosTile = OpenNewViewTile(
      title: 'see some Doggos',
      icon: Icons.child_care,
      newView: RandomDogsScrollView(),
    );

    var settingsTile = OpenNewViewTile(
      title: 'Settings',
      icon: Icons.settings,
      newView: SettingsView(
        logoutcontext: context,
      ),
      supplyLoginModel: true,
    );

    return Drawer(
      child: ListView(
        // Important: Remove any padding from the ListView.
        padding: EdgeInsets.zero,
        children: <Widget>[
          MainDrawerHeader(),
          settingsTile,
          unlimiteddoggosTile,
        ],
      ),
    );
  }
}

class OpenNewViewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget newView;
  final bool supplyLoginModel;

  const OpenNewViewTile({
    this.icon = Icons.open_in_full,
    required this.title,
    required this.newView,
    this.supplyLoginModel = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MyCardListTile1(
      icon: icon,
      text: title,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (newcontext) => supplyLoginModel
                ? ChangeNotifierProvider<LoginModel>.value(
                    value: Provider.of<LoginModel>(context),
                    child: newView,
                  )
                : newView,
          ),
        );
      },
    );
  }
}

class MainDrawerHeader extends StatelessWidget {
  const MainDrawerHeader({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      child: Center(
          child: Text(
        'Mastbau FN',
        style:
            TextStyle(fontSize: 32, color: Theme.of(context).backgroundColor),
      )),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, colors: [
          Theme.of(context).primaryColor,
          Theme.of(context).accentColor
        ]),
        //color: Theme.of(context).primaryColor,
      ),
    );
  }
}
