import 'dart:io';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart';
import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart';
import 'package:MBG_Inspektionen/backend/progressStateUpdater.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/pages/mostrecentrequest.dart';
import 'package:MBG_Inspektionen/pages/settings/developerSettings.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/login/loginModel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/openNewViewTile.dart';

/// a page where the user can change settings. it currently support [Logout]
class SettingsView extends StatelessWidget {
  final BuildContext logoutcontext;
  const SettingsView({Key? key, required this.logoutcontext}) : super(key: key);

  Widget get developerOptions => OpenNewViewTile(
        icon: Icons.developer_mode,
        title: S.current!.developerOptions,
        newView: DeveloperSettings(),
        // onPop: (_) {
        //   Options().store();
        // },
      );

  Widget get openNextRequestTile => FutureBuilder(
      future: API().local.getAllFailedRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Text('waiting to get failed requests...');
        return OpenNewViewTile(
          icon: Icons.remove_from_queue,
          title: 'next Request',
          newView: MostRecentRequestPage(
            request: (snapshot.data?.first),
          ),
        );
      });

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
            Logout(logoutcontext: logoutcontext),
            Spacer(),
            Divider(),
            Text(S.of(context).advancedSettingsHeadline),
            if (Options().canBeOffline) UploadSyncTile(),
            if (Options().canBeOffline) BackupTile(),
            if (Options().canBeOffline) openNextRequestTile,
            developerOptions,
            // DeleteCachedImages(),
          ],
        ),
      ),
    );
  }
}

class BackupTile extends StatefulWidget {
  const BackupTile({super.key});

  @override
  State<BackupTile> createState() => _BackupTileState();
}

class _BackupTileState extends State<BackupTile> {
  var loading = false;
  bool? success = null;
  var progress = 0.0;

  void onPress(BuildContext context) async {
    setState(() {
      loading = true;
    });

    Directory? appDocDirectory = await getExternalStorageDirectory();
    if (appDocDirectory == null) {
      setState(() {
        success = false;
        loading = false;
      });
      showToast('couldnt get directory');
      return;
    }
    try {
      var encoder = ZipFileEncoder();
      encoder.create(appDocDirectory.path + "/" + 'backup.zip');
      await encoder.addDirectory(Directory(appDocDirectory.path),
          onProgress: (progress) {
        setState(() {
          this.progress = progress;
        });
      });
      encoder.close();
      setState(() {
        success = true;
        loading = false;
      });
      showToast('backup created');
      Share.shareXFiles(
        [XFile(appDocDirectory.path + "/" + 'backup.zip')],
        text: 'Backup von MBG Inspektionen',
        subject: 'Backup von MBG Inspektionen',
      );
    } catch (e) {
      setState(() {
        success = false;
        loading = false;
      });
      showToast('couldnt create backup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyCardListTile1(
      icon: Icons.folder_zip,
      text: loading
          ? '${(progress * 100).floor()}%  ' + S.of(context).plsWait
          : 'Backup',
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
}

class UploadSyncTile extends StatelessWidget {
  const UploadSyncTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => ProgressStateUpdater(), child: _UploadSyncTile());
  }
}

class _UploadSyncTile extends StatefulWidget {
  const _UploadSyncTile({
    Key? key,
  }) : super(key: key);

  @override
  State<_UploadSyncTile> createState() => _UploadSyncTileState();
}

class _UploadSyncTileState extends State<_UploadSyncTile> {
  @override
  void initState() {
    super.initState();
  }

  Future<bool> get isLoading async =>
      context.read<ProgressStateUpdater>().loading;

  onPress(c) async {
    if (await isLoading) {
      showToast("already in progress");
      return;
    }

    // // slowlyRefresh();
    bool s = await FailedRequestmanager().retryFailedrequests(
      context: context,
    );
    // if (context.read<ProgressStateUpdater>().success ?? false) {
    //   try {
    //     await deleteAll(); //remove all offline data (to save storage space)
    //   } catch (e) {
    //     // wenn er nicht löschen kann war er auch nicht erfolgreich
    //     // eigtl schon, deshalb auskommentiert
    //     // s = false;
    //   }
    // }
  }

  @override
  Widget build(BuildContext context) {
    bool loading = context.watch<ProgressStateUpdater>().loading;
    double progress = context.watch<ProgressStateUpdater>().progress ?? 0.0;
    bool? success = context.watch<ProgressStateUpdater>().success;
    return MyCardListTile1(
      icon: Icons.sync,
      text: loading
          ? '${(progress * 100).floor()}%  ' + S.of(context).plsWait
          : S.of(context).uploadAndSyncData,
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
                  success ? Icons.check : Icons.error,
                  color: success ? Colors.green : Colors.red,
                )
              : null),
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
