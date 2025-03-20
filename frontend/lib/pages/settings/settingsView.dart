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
        newView: const DeveloperSettings(),
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
            const Spacer(),
            const Divider(),
            Text(S.of(context).advancedSettingsHeadline),
            if (Options().canBeOffline) const UploadSyncTile(),
            if (Options().canBeOffline) const BackupTile(),
            if (Options().canBeOffline) const OpenNextRequestTile(),
            if (Options().canBeOffline) unsetIsRunningTile,
            developerOptions,
          ],
        ),
      ),
    );
  }
}

/// Displays a page with the "next request" if available.
class OpenNextRequestTile extends StatelessWidget {
  const OpenNextRequestTile({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder(
      future: API().local.getAllFailedRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('waiting to get failed requests...');
        }
        if (snapshot.data == null || snapshot.data!.isEmpty) {
          return const Text('no failed requests');
        }
        return OpenNewViewTile(
          icon: Icons.remove_from_queue,
          title: 'next Request',
          newView: MostRecentRequestPage(
            request: snapshot.data?.first,
          ),
        );
      });
}

/// Requests storage permission if needed
Future<bool> _requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (status.isDenied) {
    // We didn't ask for permission yet or the permission has been denied before but not permanently.
    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    // Check each status
    if (statuses[Permission.storage]!.isGranted &&
        statuses[Permission.manageExternalStorage]!.isGranted) {
      return true;
    }
    // If you want to handle "permanently denied" or "restricted", do it here
    return false;
  }
  return true;
}

/// Creates a backup as ZIP and shows the progress with a progress indicator.
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
      progress = 0.0; // Reset
      success = null;
    });

    if (!await _requestStoragePermission()) {
      setState(() {
        loading = false;
        success = false;
      });
      return;
    }

    // External directory
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
      // Create MBGBackups folder
      final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
      if (!await backupDir.exists()) {
        await backupDir.create();
      }

      // Backup zip path
      final backupPath =
          '${backupDir.path}/backup-${DateTime.now().millisecondsSinceEpoch}.zip';

      await for (double progressValue in backup(backupPath)) {
        setState(() {
          progress = progressValue;
        });
      }

      showToast('Local backup finished at: $backupPath');

      setState(() {
        success = true;
        loading = false;
      });

      // Share afterwards
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
          ? SizedBox(
              height: 25,
              width: 25,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.green),
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

  void showToast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Backup function that zips everything in [localPath].
Stream<double> backup(String to) async* {
  final encoder = ZipFileEncoder();
  encoder.create(to);

  try {
    final directory = Directory(await localPath);
    final List<FileSystemEntity> entities = directory.listSync(recursive: true);

    // Calculate total size
    final int totalSize = entities
        .whereType<File>()
        .fold(0, (sum, file) => sum + file.lengthSync());
    int processedSize = 0;

    for (final entity in entities) {
      if (entity is File) {
        final String relativePath =
            entity.path.replaceFirst(directory.path, '');
        encoder.addFile(entity, relativePath);
        processedSize += entity.lengthSync();
        yield processedSize / totalSize;
      }
    }
  } finally {
    encoder.close();
  }
}

/// The tile used to upload/sync data.
class UploadSyncTile extends StatelessWidget {
  const UploadSyncTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ExtendedProgressStateUpdater(),
      child: const _UploadSyncTile(),
    );
  }
}

/// Eine erweiterte ProgressStateUpdater, die neben [loading], [progress], [success]
/// auch Infos zur aktuellen Inspektion, ETA usw. speichert.
class ExtendedProgressStateUpdater extends ProgressStateUpdater {
  String? currentInspection;
  double? currentInspectionProgress;
  String? eta;

  /// Hier ein Hilfsmethoden, um alles in einem Rutsch zu setzen.
  void setDetailedProgress({
    required double overallProgress,
    required bool? success,
    required String? inspectionId,
    required double inspProgress,
    required String etaString,
  }) {
    super.setProgress(overallProgress); // ruft notifyListeners
    if (success != null) {
      super.setSuccess(success);
    }
    currentInspection = inspectionId;
    currentInspectionProgress = inspProgress;
    eta = etaString;
    notifyListeners();
  }
}

class _UploadSyncTile extends StatefulWidget {
  const _UploadSyncTile({Key? key}) : super(key: key);

  @override
  State<_UploadSyncTile> createState() => _UploadSyncTileState();
}

class _UploadSyncTileState extends State<_UploadSyncTile> {
  /// Kleiner Helfer, ob wir gerade hochladen.
  Future<bool> get isLoading async =>
      context.read<ExtendedProgressStateUpdater>().loading;

  Future<void> onPress(BuildContext c) async {
    if (await isLoading) {
      showToast("Upload is already in progress");
      return;
    }

    // Hier starten wir das Retry. Wir übergeben onProgress, damit wir
    // neben dem Gesamtfortschritt auch Inspektions-ID, Inspektions-Fortschritt, ETA bekommen.
    final manager = FailedRequestmanager();
    bool s = await manager.retryFailedrequests(
      context: c,
      onProgress: (overall, maybeSuccess, inspId, inspProg, etaStr) {
        // Diese Methode wird bei JEDEM Fortschritt aufgerufen.
        // Wir aktualisieren unsere ExtendedProgressStateUpdater.
        context.read<ExtendedProgressStateUpdater>().setDetailedProgress(
              overallProgress: overall,
              success: maybeSuccess,
              inspectionId: inspId,
              inspProgress: inspProg,
              etaString: etaStr,
            );
      },
    );

    // Optional: Wenn du am Ende noch etwas machen möchtest:
    debugPrint("Upload-Sync finished. Success? $s");
  }

  @override
  Widget build(BuildContext context) {
    bool loading = context.watch<ExtendedProgressStateUpdater>().loading;
    double progress =
        context.watch<ExtendedProgressStateUpdater>().progress ?? 0.0;
    bool? success = context.watch<ExtendedProgressStateUpdater>().success;

    // Neue Felder:
    String? inspId =
        context.watch<ExtendedProgressStateUpdater>().currentInspection;
    double? inspProgress =
        context.watch<ExtendedProgressStateUpdater>().currentInspectionProgress;
    String? etaStr = context.watch<ExtendedProgressStateUpdater>().eta;

    // Du kannst hier flexibel auswählen, wie du die Infos anzeigen willst.
    // Beispiel: Zusätzliche Zeile mit "Aktuelle Inspektion: X, ETA: Y"
    String secondaryLine = '';
    if (loading && inspId != null) {
      final inspPct = ((inspProgress ?? 0) * 100).toStringAsFixed(0);
      secondaryLine =
          'Aktuelle Insp: $inspId, ~${inspPct}%, ETA: ${etaStr ?? ''}';
    }

    return MyCardListTile1(
      icon: Icons.sync,
      text: loading
          ? '${(progress * 100).floor()}%  ' + S.of(context).plsWait
          : S.of(context).uploadAndSyncData,
      onTap: () => onPress(context),
      // Wir bauen unten einen kleinen "Status" ein, der die Zusatzinfos zeigt
      subtitle: Text(secondaryLine),
      child: loading
          ? SizedBox(
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

  void showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Example widget to delete cached images (not implemented).
class DeleteCachedImages extends StatelessWidget {
  const DeleteCachedImages({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        // ...
      },
      child: Row(
        children: [
          const Icon(Icons.delete),
          Text(S.of(context).deleteLocalImagesButton),
        ],
      ),
    );
  }
}

/// Logout tile that resets state.
class Logout extends StatelessWidget {
  final BuildContext logoutcontext;
  const Logout({Key? key, required this.logoutcontext}) : super(key: key);

  Future _logout(BuildContext context) async {
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
  }
}
