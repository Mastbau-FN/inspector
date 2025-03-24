import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart'
    show FailedRequestmanager, sync_in_progress_str, sync_success_str;
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' show localPath;
import 'package:MBG_Inspektionen/backend/progressStateUpdater.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/pages/login/loginModel.dart';
import 'package:MBG_Inspektionen/pages/mostrecentrequest.dart';
import 'package:MBG_Inspektionen/pages/settings/developerSettings.dart';
import 'package:MBG_Inspektionen/widgets/MyListTile1.dart';
import 'package:MBG_Inspektionen/widgets/openNewViewTile.dart';
import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart'
    show UploadProgressWriter;
import 'package:MBG_Inspektionen/pages/settings/backupManagementView.dart';

/// A page where the user can change settings. It currently supports [Logout].
class SettingsView extends StatelessWidget {
  final BuildContext logoutcontext;
  const SettingsView({Key? key, required this.logoutcontext}) : super(key: key);

  Widget get developerOptions => OpenNewViewTile(
        icon: Icons.developer_mode,
        title: S.current!.developerOptions,
        newView: const DeveloperSettings(),
      );

  Widget get backupManagementTile => OpenNewViewTile(
        icon: Icons.folder,
        title: 'Backups verwalten',
        newView: const BackupManagementView(),
      );

  Widget get unsetIsRunningTile => MyCardListTile1(
        icon: Icons.remove_circle_outline,
        text: 'unset isRunning',
        onTap: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          // Verwende hier die Konstante aus failedRequestManager.dart
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
            if (Options().canBeOffline) backupManagementTile,
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

    if (statuses[Permission.storage]!.isGranted &&
        statuses[Permission.manageExternalStorage]!.isGranted) {
      return true;
    }
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
  String currentFile = '';
  String eta = '';

  void onPress(BuildContext context) async {
    setState(() {
      loading = true;
      progress = 0.0;
      success = null;
      currentFile = '';
      eta = '';
    });

    if (!await _requestStoragePermission()) {
      setState(() {
        loading = false;
        success = false;
      });
      showToast('Could not get external directory');
      return;
    }

    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      setState(() {
        success = false;
        loading = false;
      });
      showToast('Could not get external directory');
      return;
    }

    try {
      final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
      if (!await backupDir.exists()) {
        await backupDir.create();
      }

      final backupPath =
          '${backupDir.path}/backup-${DateTime.now().millisecondsSinceEpoch}.zip';

      await for (BackupProgress progressValue in backup(backupPath)) {
        setState(() {
          progress = progressValue.progress;
          currentFile = progressValue.currentFile;
          eta = progressValue.eta;
        });
      }

      showToast('Local backup finished at: $backupPath');

      setState(() {
        success = true;
        loading = false;
      });

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
    String tileText = loading
        ? '${(progress * 100).floor()}%  Bitte warten \n Aktuelle Datei: $currentFile \n ETA: $eta'
        : 'Backup';

    return MyCardListTile1(
      icon: Icons.folder_zip,
      text: tileText,
      onTap: () => onPress(context),
      child: loading
          ? SizedBox(
              height: 25,
              width: 25,
              child: CircularProgressIndicator(
                value: progress,
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

  void showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class BackupProgress {
  final double progress;
  final String currentFile;
  final String eta;

  BackupProgress({
    required this.progress,
    required this.currentFile,
    required this.eta,
  });
}

/// Backups everything in localPath as a zip, providing a progress stream.
Stream<BackupProgress> backup(String to) async* {
  final encoder = ZipFileEncoder();
  encoder.create(to);

  try {
    final directory = Directory(await localPath);
    final entities = directory.listSync(recursive: true);

    final totalSize = entities.whereType<File>().fold<int>(
          0,
          (sum, file) => sum + file.lengthSync(),
        );
    int processedSize = 0;
    DateTime startTime = DateTime.now();

    for (final entity in entities) {
      if (entity is File) {
        final relativePath = entity.path.replaceFirst(directory.path, '');
        encoder.addFile(entity, relativePath);
        processedSize += entity.lengthSync();

        // Berechne ETA
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        final speed = processedSize / elapsed;
        final remaining = totalSize - processedSize;
        final etaMs = remaining / speed;
        final etaDuration = Duration(milliseconds: etaMs.round());
        final etaStr = etaDuration.inMinutes >= 1
            ? '${etaDuration.inMinutes} min'
            : '${etaDuration.inSeconds} s';

        yield BackupProgress(
          progress: processedSize / totalSize,
          currentFile: relativePath,
          eta: etaStr,
        );
      }
    }
  } finally {
    encoder.close();
  }
}

/// Kachel für das Hochladen / Synchronisieren mit dem Server
class UploadSyncTile extends StatelessWidget {
  const UploadSyncTile({super.key});

  @override
  Widget build(BuildContext context) {
    // Hier kommt nun **die** ExtendedProgressStateUpdater-Klasse aus progressStateUpdater.dart
    return ChangeNotifierProvider(
      create: (_) => ExtendedProgressStateUpdater(),
      child: const _UploadSyncTile(),
    );
  }
}

class _UploadSyncTile extends StatefulWidget {
  const _UploadSyncTile({Key? key}) : super(key: key);

  @override
  State<_UploadSyncTile> createState() => _UploadSyncTileState();
}

class _UploadSyncTileState extends State<_UploadSyncTile> {
  bool isSynced = false;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    final failedReqs = await API().local.getAllFailedRequests() ?? [];
    setState(() {
      isSynced = failedReqs.isEmpty;
    });
  }

  Future<void> onPress() async {
    if (isSynced) {
      showToast('Alle Inspektionen sind bereits synchronisiert');
      return;
    }

    final updater = context.read<ExtendedProgressStateUpdater>();

    if (updater.loading) {
      // Upload läuft schon
      return;
    }

    debugPrint('Starting backup and sync process...');

    // Fortschritt zurücksetzen
    updater.setDetailedProgress(
      overallProgress: 0.0,
      success: null,
      inspectionId: '',
      inspProgress: 0.0,
      etaString: '',
    );

    // Zuerst Backup erstellen
    bool backupSuccess = false;
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      try {
        final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
        if (!await backupDir.exists()) {
          await backupDir.create();
        }

        final backupPath =
            '${backupDir.path}/backup-${DateTime.now().millisecondsSinceEpoch}.zip';
        debugPrint('Starting backup to: $backupPath');

        final upsn = UploadProgressWriter();
        await upsn.awaitInitDone();
        upsn.setLoading(true);
        await upsn.setProgress(0.0); // Fortschritt zurücksetzen

        // Backup durchführen
        await for (BackupProgress progressValue in backup(backupPath)) {
          debugPrint(
              'Backup progress: ${(progressValue.progress * 100).toStringAsFixed(1)}%');
          // Backup-Fortschritt anzeigen
          await upsn.setBackupProgress(progressValue);
          updater.setDetailedProgress(
            overallProgress: progressValue.progress,
            success: null,
            inspectionId: 'Backup',
            inspProgress: progressValue.progress,
            etaString: '',
          );
        }
        debugPrint('Backup completed successfully');
        backupSuccess = true;
        upsn.setLoading(false);
        upsn.setSuccess(true);
      } catch (e) {
        debugPrint('Backup failed: $e');
        showToast('Backup fehlgeschlagen');
        return;
      }
    }

    // Nur wenn Backup erfolgreich war, Sync starten
    if (backupSuccess) {
      debugPrint('Starting sync process...');
      bool success = await FailedRequestmanager().retryFailedrequests(
        context: context,
        onProgress: (overall, maybeSuccess, inspId, inspProg, etaStr) {
          debugPrint(
              'Sync progress: ${(overall * 100).toStringAsFixed(1)}% - Current inspection: $inspId');
          // Jedes Mal "Zwischenstand" -> Updater benachrichtigen
          updater.setDetailedProgress(
            overallProgress: overall,
            success: maybeSuccess, // kann null sein, wenn noch nicht fertig
            inspectionId: inspId,
            inspProgress: inspProg,
            etaString: etaStr,
          );
        },
      );
      debugPrint('Sync finished: $success');
      await _checkSyncStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final updater = context.watch<ExtendedProgressStateUpdater>();
    final loading = updater.loading;
    final progress = updater.progress ?? 0.0;
    final success = updater.success;

    // Neue Felder
    final inspId = updater.currentInspection ?? '';
    final inspPct = ((updater.currentInspectionProgress ?? 0) * 100).round();
    final eta = updater.eta ?? '';

    // Zeile mit Infos
    String secondLine = '';
    if (loading) {
      if (inspId == 'Backup') {
        secondLine = 'Backup';
      } else if (inspId.isNotEmpty) {
        secondLine = 'Sync';
      }
    }

    // Für eine mehrzeilige Anzeige einfach einen Zeilenumbruch benutzen:
    final tileText = loading
        ? '${inspId == 'Backup' ? 'Schritt 1/2' : 'Schritt 2/2'}: \n$secondLine'
        : isSynced
            ? 'Alles synchronisiert'
            : 'Synchronisierung \n mit Server';

    return MyCardListTile1(
      icon: Icons.sync,
      text: tileText,
      onTap: onPress,
      child: loading
          ? Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${(progress * 100).floor()}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    height: 25,
                    width: 25,
                    child: CircularProgressIndicator(
                      value: progress,
                    ),
                  ),
                ],
              ),
            )
          : (isSynced
              ? Icon(Icons.check_circle, color: Colors.green)
              : (success != null
                  ? Icon(
                      success ? Icons.check : Icons.error,
                      color: success ? Colors.green : Colors.red,
                    )
                  : null)),
    );
  }
}

/// Einfache Logout-Kachel.
class Logout extends StatelessWidget {
  final BuildContext logoutcontext;
  const Logout({Key? key, required this.logoutcontext}) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    // Hier muss ein LoginModel in der Provider-Hierarchie verfügbar sein
    // (z.B. via MultiProvider).
    // Andernfalls bitte anpassen.
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
