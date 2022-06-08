import 'package:MBG_Inspektionen/assets/consts.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/login/loginModel.dart';
import 'package:provider/provider.dart';

import '../../backend/api.dart';
import '../../generated/l10n.dart';

/// a page where the user can change settings. it currently support [Logout]
class SettingsView extends StatelessWidget {
  final BuildContext logoutcontext;
  const SettingsView({Key? key, required this.logoutcontext}) : super(key: key);

  Widget get uploadSyncTile => MyCardListTile1(
        icon: Icons.sync,
        text: S.current.uploadAndSyncData,
        onTap: Backend().retryFailedrequests,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).settings),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Logout(
              logoutcontext: logoutcontext,
            ),
            Spacer(),
            Divider(),
            Text(S.of(context).advancedSettingsHeadline),
            if (Options.canBeOffline) uploadSyncTile,
            // DeleteCachedImages(),
          ],
        ),
      ),
    );
  }
}

class DeleteCachedImages extends StatelessWidget {
  const DeleteCachedImages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
        onPressed: () {},
        child: Row(
          children: [
            Icon(Icons.delete),
            Text(S.of(context).deleteLocalImagesButton),
          ],
        ));
  }
}

class Logout extends StatelessWidget {
  final BuildContext logoutcontext;
  const Logout({Key? key, required this.logoutcontext}) : super(key: key);

  /// logs the user out and resets app state accordingly
  Future _logout(context) async {
    /*Navigator.popUntil(
        context,
        /*MaterialPageRoute(
      builder: (context) {
        Provider.of<LoginModel>(context, listen: false).logout();
        return LoginWrapper('mastbau');
      },
    ),*/
        (route) => route.isFirst);*/
    await Provider.of<LoginModel>(context, listen: false).logout();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MyCardListTile1(
      icon: Icons.exit_to_app,
      text: S.of(context).logoutButton,
      onTap: () => _logout(context),
    );
    // return TextButton(
    //     onPressed: () async {
    //       await _logout(context);
    //     },
    //     child: Row(
    //       children: [
    //         Icon(Icons.logout),
    //         Text("Logout"),
    //       ],
    //     ));
  }
}
