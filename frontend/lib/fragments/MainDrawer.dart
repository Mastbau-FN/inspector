import 'package:MBG_Inspektionen/Options.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/login/loginModel.dart';
import 'package:MBG_Inspektionen/pages/settings/settingsView.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/fragments/RandomDogsScrollView.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../generated/l10n.dart';
import '../widgets/openNewViewTile.dart';

class MainDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var unlimiteddoggosTile = OpenNewViewTile(
      title: S.of(context).seeSomeDoggos,
      icon: Icons.child_care,
      newView: RandomDogsScrollView(),
    );

    var settingsTile = OpenNewViewTile(
      title: S.of(context).settings,
      icon: Icons.settings,
      newView: SettingsView(
        logoutcontext: context,
      ),
      supplyLoginModel: true,
    );

    return Drawer(
      child: Column(
        // Important: Remove any padding from the ListView.
        //padding: EdgeInsets.zero,
        children: <Widget>[
          MainDrawerHeader(),
          settingsTile,
          if (Options().showDoggo) unlimiteddoggosTile,
          Spacer(),
          if (Options.canBeOffline) UploadSyncTile(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: VersionInfo(),
            ),
          ),
        ],
      ),
    );
  }
}

class VersionInfo extends StatelessWidget {
  const VersionInfo({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          return Text(
            (snapshot.data?.appName ?? 'MBG Inspektionen') +
                ' ' +
                (snapshot.data?.buildNumber ?? '...'),
          );
        });
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
        child: Image(image: AssetImage('lib/assets/MBG.webp')),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, colors: [
          Theme.of(context).primaryColorDark.withAlpha(200),
          Theme.of(context).canvasColor,
          //Theme.of(context).primaryColor.withAlpha(250),
        ]),
        //color: Theme.of(context).primaryColor,
      ),
    );
  }
}
