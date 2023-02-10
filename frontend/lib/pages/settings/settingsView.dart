import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/pages/settings/developerSettings.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/login/loginModel.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n.dart';
import '../../widgets/openNewViewTile.dart';

/// a page where the user can change settings. it currently support [Logout]
class SettingsView extends StatelessWidget {
  final BuildContext logoutcontext;
  const SettingsView({Key? key, required this.logoutcontext}) : super(key: key);

  Widget get developerOptions => OpenNewViewTile(
        icon: Icons.developer_mode,
        title: AppLocalizations.of(context)!.developerOptions,
        newView: DeveloperSettings(),
        // onPop: (_) {
        //   Options().store();
        // },
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Logout(logoutcontext: logoutcontext),
            Spacer(),
            Divider(),
            Text(AppLocalizations.of(context)!.advancedSettingsHeadline),
            if (Options().canBeOffline) UploadSyncTile(),
            developerOptions,
            // DeleteCachedImages(),
          ],
        ),
      ),
    );
  }
}

class UploadSyncTile extends StatefulWidget {
  const UploadSyncTile({
    Key? key,
  }) : super(key: key);

  @override
  State<UploadSyncTile> createState() => _UploadSyncTileState();
}

class _UploadSyncTileState extends State<UploadSyncTile> {
  bool loading = false;
  bool? success;
  double progress = 0;
  onPress(c) async {
    setState(() {
      loading = true;
    });
    bool s = await FailedRequestmanager().retryFailedrequests(
        context: context,
        onProgress: (p) => setState(() {
              print(p);
              progress = p;
            }));
    if (s) {
      try {
        await deleteAll(); //remove all offline data (to save storage space)
      } catch (e) {
        // wenn er nicht löschen kann war er auch nicht erfolgreich
        // eigtl schon, deshalb auskommentiert
        // s = false;
      }
    }

    setState(() {
      progress = 0;
      success = s;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => MyCardListTile1(
        icon: Icons.sync,
        text: loading
            ? '${(progress * 100).floor()}%  ' +
                AppLocalizations.of(context)!.plsWait
            : AppLocalizations.of(context)!.uploadAndSyncData,
        onTap: () => onPress(context),
        child: loading
            ? Container(
                height: 25,
                width: 25,
                // color: Colors.red,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: LoadingView(),
                    ),
                    CircularProgressIndicator(
                      color: Colors.green,
                      value: progress,
                    ),
                  ],
                ),
              )
            : (success != null
                ? Icon(
                    success! ? Icons.check : Icons.error,
                    color: success! ? Colors.green : Colors.red,
                  )
                : null),
      );
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
            Text(AppLocalizations.of(context)!.deleteLocalImagesButton),
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
      text: AppLocalizations.of(context)!.logoutButton,
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
