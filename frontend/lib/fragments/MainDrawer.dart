import 'package:MBG_Inspektionen/options.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/settings/settingsView.dart';
import 'package:MBG_Inspektionen/fragments/RandomDogsScrollView.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../generated/l10n.dart';
import '../widgets/openNewViewTile.dart';

class MainDrawer extends StatelessWidget {
  final bool showUpload;
  final List<Widget> children;

  const MainDrawer({
    Key? key,
    this.showUpload = false,
    this.children = const [],
  }) : super(key: key);

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
          ...children,
          // if (Options().showDoggo) unlimiteddoggosTile,
          Spacer(),
          if (showUpload && Options().canBeOffline) UploadSyncTile(),
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
        child: SvgPicture.asset(
          'lib/assets/icon_smooth.svg',
          semanticsLabel: 'MBG Logo',
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(begin: Alignment.topLeft, colors: [
      //     Theme.of(context).primaryColorDark.withAlpha(200),
      //     Theme.of(context).canvasColor,
      //     //Theme.of(context).primaryColor.withAlpha(250),
      //   ]),
      //   //color: Theme.of(context).primaryColor,
      // ),
    );
  }
}
