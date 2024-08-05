// import 'dart:async';
// import 'dart:io';

// import 'package:MBG_Inspektionen/backend/api.dart';
// import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
// import 'package:MBG_Inspektionen/backend/offlineProvider.dart' show localPath;
// import 'package:MBG_Inspektionen/backend/progressStateUpdater.dart';
// import 'package:MBG_Inspektionen/helpers/toast.dart';
// import 'package:MBG_Inspektionen/options.dart';
// import 'package:MBG_Inspektionen/pages/mostrecentrequest.dart';
// import 'package:MBG_Inspektionen/pages/settings/developerSettings.dart';
// import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
// import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
// import 'package:archive/archive_io.dart';
// import 'package:flutter/material.dart';
// import 'package:MBG_Inspektionen/pages/login/loginModel.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';

// import 'package:MBG_Inspektionen/l10n/locales.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../../widgets/openNewViewTile.dart';

// import 'package:MBG_Inspektionen/backend/offlineProvider.dart' show localPath;

// /// a page where the user can change settings. it currently support [Logout]
// class SettingsView extends StatelessWidget {
//   final BuildContext logoutcontext;
//   const SettingsView({Key? key, required this.logoutcontext}) : super(key: key);

//   Widget get developerOptions => OpenNewViewTile(
//         icon: Icons.developer_mode,
//         title: S.current!.developerOptions,
//         newView: DeveloperSettings(),
//         // onPop: (_) {
//         //   Options().store();
//         // },
//       );

//   Widget get unsetIsRunningTile => MyCardListTile1(
//         icon: Icons.remove_circle_outline,
//         text: 'unset isRunning',
//         onTap: () async {
//           SharedPreferences prefs = await SharedPreferences.getInstance();
//           prefs.setBool(sync_in_progress_str, false);
//         },
//       );

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(S.of(context).settings),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             Logout(logoutcontext: logoutcontext),
//             Spacer(),
//             Divider(),
//             Text(S.of(context).advancedSettingsHeadline),
//             if (Options().canBeOffline) UploadSyncTile(),
//             if (Options().canBeOffline) BackupTile(),
//             if (Options().canBeOffline) OpenNextRequestTile(),
//             if (Options().canBeOffline) unsetIsRunningTile,
//             developerOptions,
//             // DeleteCachedImages(),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class OpenNextRequestTile extends StatelessWidget {
//   const OpenNextRequestTile({
//     super.key,
//   });

//   @override
//   Widget build(BuildContext context) => FutureBuilder(
//       future: API().local.getAllFailedRequests(),
//       builder: (context, snapshot) {
//         if (!snapshot.hasData) return Text('waiting to get failed requests...');
//         return OpenNewViewTile(
//           icon: Icons.remove_from_queue,
//           title: 'next Request',
//           newView: MostRecentRequestPage(
//             request: (snapshot.data?.first),
//           ),
//         );
//       });
// }

// class BackupTile extends StatefulWidget {
//   const BackupTile({super.key});

//   @override
//   State<BackupTile> createState() => _BackupTileState();
// }

// class _BackupTileState extends State<BackupTile> {
//   var loading = false;
//   bool? success = null;
//   var progress = 0.0;

//   void onPress(BuildContext context) async {
//     setState(() {
//       loading = true;
//     });

//     Directory? appDocDirectory = await getExternalStorageDirectory();
//     if (appDocDirectory == null) {
//       setState(() {
//         success = false;
//         loading = false;
//       });
//       showToast('couldnt get directory');
//       return;
//     }
//     try {
//       final backupPath = appDocDirectory.path +
//           '/backup-${DateTime.now().millisecondsSinceEpoch}.zip';
//       await for (var progress in backup(backupPath)) {
//         setState(() {
//           this.progress = progress;
//         });
//       }
//       setState(() {
//         success = true;
//         loading = false;
//       });
//       showToast('backup created');
//       Share.shareXFiles(
//         [XFile(appDocDirectory.path + "/" + 'backup.zip')],
//         text: 'Backup von MBG Inspektionen',
//         subject: 'Backup von MBG Inspektionen',
//       );
//     } catch (e) {
//       setState(() {
//         success = false;
//         loading = false;
//       });
//       showToast('couldnt create backup');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MyCardListTile1(
//       icon: Icons.folder_zip,
//       text: loading
//           ? '${(progress * 100).floor()}%  ' + S.of(context).plsWait
//           : 'Backup',
//       onTap: () => onPress(context),
//       child: loading
//           ? Container(
//               height: 25,
//               width: 25,
//               // color: Colors.red,
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(4.0),
//                     child: LoadingView(),
//                   ),
//                   CircularProgressIndicator(
//                     color: Colors.green,
//                     value: progress,
//                   ),
//                 ],
//               ),
//             )
//           : (success != null
//               ? Icon(
//                   success! ? Icons.check : Icons.error,
//                   color: success! ? Colors.green : Colors.red,
//                 )
//               : null),
//     );
//   }
// }

// Stream<double> backup(String to) {
//   var encoder = ZipFileEncoder();
//   encoder.create(to);

//   StreamController<double> controller = StreamController<double>();
//   () async {
//     await encoder.addDirectory(Directory(await localPath),
//         onProgress: (progress) {
//       controller.add(progress);
//     });
//     encoder.close();
//     controller.close();
//   }();
//   return controller.stream;
// }

// class UploadSyncTile extends StatelessWidget {
//   const UploadSyncTile({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ChangeNotifierProvider(
//         create: (_) => ProgressStateUpdater(), child: _UploadSyncTile());
//   }
// }

// class _UploadSyncTile extends StatefulWidget {
//   const _UploadSyncTile({
//     Key? key,
//   }) : super(key: key);

//   @override
//   State<_UploadSyncTile> createState() => _UploadSyncTileState();
// }

// class _UploadSyncTileState extends State<_UploadSyncTile> {
//   @override
//   void initState() {
//     super.initState();
//   }

//   Future<bool> get isLoading async =>
//       context.read<ProgressStateUpdater>().loading;

//   onPress(c) async {
//     if (await isLoading) {
//       showToast("already in progress");
//       return;
//     }

//     // // slowlyRefresh();
//     // ignore: unused_local_variable
//     bool s = await FailedRequestmanager().retryFailedrequests(
//       context: context,
//     );
//     // if (context.read<ProgressStateUpdater>().success ?? false) {
//     //   try {
//     //     await deleteAll(); //remove all offline data (to save storage space)
//     //   } catch (e) {
//     //     // wenn er nicht löschen kann war er auch nicht erfolgreich
//     //     // eigtl schon, deshalb auskommentiert
//     //     // s = false;
//     //   }
//     // }
//   }

//   @override
//   Widget build(BuildContext context) {
//     bool loading = context.watch<ProgressStateUpdater>().loading;
//     double progress = context.watch<ProgressStateUpdater>().progress ?? 0.0;
//     bool? success = context.watch<ProgressStateUpdater>().success;
//     return MyCardListTile1(
//       icon: Icons.sync,
//       text: loading
//           ? '${(progress * 100).floor()}%  ' + S.of(context).plsWait
//           : S.of(context).uploadAndSyncData,
//       onTap: () => onPress(context),
//       child: loading
//           ? Container(
//               height: 25,
//               width: 25,
//               // color: Colors.red,
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(4.0),
//                     child: LoadingView(),
//                   ),
//                   CircularProgressIndicator(
//                     color: Colors.green,
//                     value: progress,
//                   ),
//                 ],
//               ),
//             )
//           : (success != null
//               ? Icon(
//                   success ? Icons.check : Icons.error,
//                   color: success ? Colors.green : Colors.red,
//                 )
//               : null),
//     );
//   }
// }

// class DeleteCachedImages extends StatelessWidget {
//   const DeleteCachedImages({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return TextButton(
//         onPressed: () {},
//         child: Row(
//           children: [
//             Icon(Icons.delete),
//             Text(S.of(context).deleteLocalImagesButton),
//           ],
//         ));
//   }
// }

// class Logout extends StatelessWidget {
//   final BuildContext logoutcontext;
//   const Logout({Key? key, required this.logoutcontext}) : super(key: key);

//   /// logs the user out and resets app state accordingly
//   Future _logout(context) async {
//     /*Navigator.popUntil(
//         context,
//         /*MaterialPageRoute(
//       builder: (context) {
//         Provider.of<LoginModel>(context, listen: false).logout();
//         return LoginWrapper('mastbau');
//       },
//     ),*/
//         (route) => route.isFirst);*/
//     await Provider.of<LoginModel>(context, listen: false).logout();
//     Navigator.popUntil(context, (route) => route.isFirst);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return MyCardListTile1(
//       icon: Icons.exit_to_app,
//       text: S.of(context).logoutButton,
//       onTap: () => _logout(context),
//     );
//     // return TextButton(
//     //     onPressed: () async {
//     //       await _logout(context);
//     //     },
//     //     child: Row(
//     //       children: [
//     //         Icon(Icons.logout),
//     //         Text("Logout"),
//     //       ],
//     //     ));
//   }
// }

import 'dart:async';
import 'dart:io';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' show localPath;
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
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/openNewViewTile.dart';

import 'package:MBG_Inspektionen/backend/offlineProvider.dart' show localPath;

/// A page where the user can change settings. It currently supports [Logout].
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

  Widget get unsetIsRunningTile => MyCardListTile1(
        icon: Icons.remove_circle_outline,
        text: 'unset isRunning',
        onTap: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setBool(sync_in_progress_str, false);
        },
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
            Logout(logoutcontext: logoutcontext),
            Spacer(),
            Divider(),
            Text(S.of(context).advancedSettingsHeadline),
            if (Options().canBeOffline) UploadSyncTile(),
            if (Options().canBeOffline) BackupTile(),
            if (Options().canBeOffline) OpenNextRequestTile(),
            if (Options().canBeOffline) unsetIsRunningTile,
            developerOptions,
            // DeleteCachedImages(),
          ],
        ),
      ),
    );
  }
}

class OpenNextRequestTile extends StatelessWidget {
  const OpenNextRequestTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder(
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
}

Future<bool> _requestStoragePermission() async {
  // Request storage permissions
  var status = await Permission.storage.status;
  if (status.isDenied) {
    // We didn't ask for permission yet or the permission has been denied before but not permanently.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    // Check each status and handle accordingly
    if (statuses[Permission.storage]!.isGranted &&
        statuses[Permission.manageExternalStorage]!.isGranted) {
      return true;
    }
    return false;
  }
  return status.isGranted;
}

// Define the BackupTile widget
class BackupTile extends StatefulWidget {
  const BackupTile({super.key});

  @override
  State<BackupTile> createState() => _BackupTileState();
}

class _BackupTileState extends State<BackupTile> {
  bool loading = false;
  bool? success;
  double progress = 0.0;

  void onPress(BuildContext context) async {
    setState(() {
      loading = true;
      progress = 0.0; // Reset progress before starting
    });

    // Request storage permission
    if (!await _requestStoragePermission()) {
      showToast('Storage permission not granted');
      setState(() {
        loading = false;
        success = false;
      });
      return;
    }

    // Get the user's external storage directory
    Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      setState(() {
        success = false;
        loading = false;
      });
      showToast('Could not get external directory');
      return;
    }

    try {
      // Create MBGBackups folder in external storage
      final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
      if (!await backupDir.exists()) {
        await backupDir.create();
      }

      // Define the backup file path within MBGBackups
      final backupPath =
          '${backupDir.path}/backup-${DateTime.now().millisecondsSinceEpoch}.zip';

      // Perform backup and update progress
      await for (double progressValue in backup(backupPath)) {
        setState(() {
          progress = progressValue;
        });
      }

      // Show toast when backup is complete
      showToast('Local backup finished and saved at: $backupPath');

      // Reset state to show completion
      setState(() {
        success = true;
        loading = false;
      });

      // After backup completion, start sharing
      Share.shareXFiles(
        [XFile(backupPath)],
        text: 'Backup from MBG Inspektionen',
        subject: 'Backup from MBG Inspektionen',
      );
    } catch (e) {
      setState(() {
        success = false;
        loading = false;
      });
      showToast('Could not create backup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyCardListTile1(
      icon: Icons.folder_zip,
      text: loading
          ? '${(progress * 100).floor()}%  ' + 'Please wait...'
          : 'Backup',
      onTap: () => onPress(context),
      child: loading
          ? Container(
              height: 25,
              width: 25,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      value: progress,
                    ),
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

  void showToast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// Stream-based backup function
Stream<double> backup(String to) async* {
  final encoder = ZipFileEncoder();
  encoder.create(to);

  try {
    // Directory for files to be backed up
    final directory = Directory(await localPath);

    // List all files and directories recursively
    final List<FileSystemEntity> entities = directory.listSync(recursive: true);

    // Calculate the total size of all files for progress tracking
    final int totalSize = entities
        .whereType<File>()
        .fold(0, (sum, file) => sum + file.lengthSync());
    int processedSize = 0;

    // Iterate over each entity
    for (final entity in entities) {
      if (entity is File) {
        // Get the relative path of the file
        final String relativePath =
            entity.path.replaceFirst(directory.path, '');

        // Add file to the ZIP while preserving folder structure
        encoder.addFile(entity, relativePath);

        // Update processed size
        processedSize += entity.lengthSync();

        // Yield progress as a percentage of total size
        yield processedSize / totalSize;
      }
    }
  } finally {
    // Ensure the encoder is closed properly
    encoder.close();
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
    // ignore: unused_local_variable
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

  /// Logs the user out and resets app state accordingly.
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
