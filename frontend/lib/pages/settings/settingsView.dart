import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart'
    show
        FailedRequestmanager,
        sync_in_progress_str,
        sync_success_str,
        GroupedInspection;
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
class SettingsView extends StatefulWidget {
  final BuildContext logoutcontext;
  const SettingsView({super.key, required this.logoutcontext});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  Future<void> _logout() async {
    await Provider.of<LoginModel>(widget.logoutcontext, listen: false).logout();
    Navigator.popUntil(widget.logoutcontext, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: ChangeNotifierProvider(
        create: (_) => InspectionData(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyCardListTile1(
                  icon: Icons.exit_to_app,
                  text: S.of(context).logoutButton,
                  onTap: _logout,
                ),
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
        ),
      ),
    );
  }

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
Future<bool> _requestStoragePermission(BuildContext context) async {
  // Prüfe Speicherberechtigung
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    debugPrint('Speicherberechtigung fehlt');

    // Versuche zunächst, die Berechtigung direkt anzufordern
    final result = await Permission.storage.request();
    if (result.isGranted) {
      debugPrint('Speicherberechtigung wurde gewährt');
    } else {
      // Zeige Dialog zum Öffnen der Einstellungen
      final bool? shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Speicherzugriff erforderlich'),
            content: Text(
                'Für das Erstellen von Backups benötigt die App Zugriff auf den Speicher. Möchten Sie die Einstellungen öffnen, um die Berechtigung zu erteilen?'),
            actions: <Widget>[
              TextButton(
                child: Text('Abbrechen'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('Einstellungen öffnen'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (shouldOpenSettings == true) {
        debugPrint('Öffne App-Einstellungen für Speicherberechtigung...');
        await openAppSettings();

        // Warte kurz und prüfe dann erneut
        await Future.delayed(Duration(seconds: 2));
        status = await Permission.storage.status;
        if (!status.isGranted) {
          debugPrint('Speicherberechtigung immer noch nicht erlaubt');
          return false;
        }
        debugPrint('Speicherberechtigung wurde erteilt');
      } else {
        debugPrint('Benutzer hat abgebrochen');
        return false;
      }
    }
  }

  // Prüfe externe Speicherberechtigung (für Android 11+)
  var externalStatus = await Permission.manageExternalStorage.status;
  if (!externalStatus.isGranted) {
    debugPrint('Externe Speicherberechtigung fehlt');

    // Versuche zunächst, die Berechtigung direkt anzufordern
    final result = await Permission.manageExternalStorage.request();
    if (result.isGranted) {
      debugPrint('Externe Speicherberechtigung wurde gewährt');
    } else {
      // Zeige Dialog zum Öffnen der Einstellungen
      final bool? shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Erweiterte Speicherberechtigung erforderlich'),
            content: Text(
                'Für das Erstellen von Backups benötigt die App erweiterten Zugriff auf den Speicher. Möchten Sie die Einstellungen öffnen, um die Berechtigung zu erteilen?'),
            actions: <Widget>[
              TextButton(
                child: Text('Abbrechen'),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: Text('Einstellungen öffnen'),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (shouldOpenSettings == true) {
        debugPrint(
            'Öffne App-Einstellungen für externe Speicherberechtigung...');
        await openAppSettings();

        // Warte kurz und prüfe dann erneut
        await Future.delayed(Duration(seconds: 2));
        externalStatus = await Permission.manageExternalStorage.status;
        if (!externalStatus.isGranted) {
          debugPrint('Externe Speicherberechtigung immer noch nicht erlaubt');
          return false;
        }
        debugPrint('Externe Speicherberechtigung wurde erteilt');
      } else {
        debugPrint('Benutzer hat abgebrochen');
        return false;
      }
    }
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
    // Prüfe zuerst die Berechtigungen, bevor wir irgendetwas anderes tun
    if (!await _requestStoragePermission(context)) {
      showToast('Speicherberechtigung ist erforderlich für das Backup');
      return;
    }

    setState(() {
      loading = true;
      progress = 0.0;
      success = null;
      currentFile = '';
      eta = '';
    });

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
      create: (_) => InspectionData(),
      child: ChangeNotifierProvider(
        create: (_) => ExtendedProgressStateUpdater(),
        child: const _UploadSyncTile(),
      ),
    );
  }
}

class InspectionData extends ChangeNotifier {
  List<String?> completedInspections = [];
  Map<String?, double> inspectionProgress = {};
  Map<String?, List<String>> inspectionRequests = {};
  List<GroupedInspection>? analyzedInspections;
  bool isAnalyzing = false;

  void reset() {
    completedInspections = [];
    inspectionProgress = {};
    inspectionRequests = {};
    analyzedInspections = null;
    isAnalyzing = false;
    notifyListeners();
  }

  void updateProgress(String? pjNr, double progress) {
    if (pjNr != null) {
      inspectionProgress[pjNr] = progress;
      notifyListeners();
    }
  }

  void markAsCompleted(String? pjNr) {
    if (pjNr != null && !completedInspections.contains(pjNr)) {
      completedInspections.add(pjNr);
      notifyListeners();
    }
  }

  void setAnalyzedInspections(List<GroupedInspection> inspections) {
    analyzedInspections = inspections;
    notifyListeners();
  }

  void setAnalyzing(bool analyzing) {
    isAnalyzing = analyzing;
    notifyListeners();
  }
}

class _UploadSyncTile extends StatefulWidget {
  const _UploadSyncTile({Key? key}) : super(key: key);

  @override
  State<_UploadSyncTile> createState() => _UploadSyncTileState();
}

class _UploadSyncTileState extends State<_UploadSyncTile> {
  bool isSynced = false;
  bool showCompleted = false;

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

  Future<void> _analyzeRequests() async {
    final inspectionData = context.read<InspectionData>();
    if (inspectionData.isAnalyzing) {
      debugPrint('Analyse läuft bereits, überspringe...');
      return;
    }

    debugPrint('Starte Analyse der Requests...');
    inspectionData.setAnalyzing(true);

    try {
      final inspections =
          await FailedRequestmanager().getGroupedFailedRequests();
      debugPrint(
          'Analyse abgeschlossen. Gefundene Inspektionen: ${inspections.length}');
      inspectionData.setAnalyzedInspections(inspections);
    } catch (e) {
      debugPrint('Error analyzing requests: $e');
      showToast('Fehler bei der Analyse der Requests');
    } finally {
      inspectionData.setAnalyzing(false);
    }
  }

  Future<void> onPress() async {
    if (isSynced) {
      showToast('Alle Inspektionen sind bereits synchronisiert');
      return;
    }

    final inspectionData = context.read<InspectionData>();
    inspectionData.reset();

    // WICHTIG: Benachrichtigungen neu initialisieren, um sicherzustellen, dass nur der Erfolgskanal einen Ton hat
    await reinitializeNotificationChannels();

    // Starte die Analyse
    await _analyzeRequests();

    ExtendedProgressStateUpdater? updater;
    try {
      updater = context.read<ExtendedProgressStateUpdater>();
    } catch (e) {
      debugPrint('ExtendedProgressStateUpdater not available: $e');
    }

    if (updater?.loading ?? false) {
      return;
    }

    final failedReqs = await API().local.getAllFailedRequests();
    if (failedReqs == null || failedReqs.isEmpty) {
      debugPrint('No failed requests found, skipping backup and sync');
      showToast('Keine Inspektionen zum Synchronisieren vorhanden');
      return;
    }

    // Internetverbindung prüfen
    debugPrint('Checking internet connection...');
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('Connectivity result: $connectivityResult');

    // Prüfe auch die tatsächliche Internetverbindung
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      debugPrint('Internet check result: $hasInternet');
    } catch (e) {
      debugPrint('Internet check failed: $e');
      hasInternet = false;
    }

    if (connectivityResult == ConnectivityResult.none || !hasInternet) {
      debugPrint('No internet connection detected');
      showToast('Keine Internetverbindung');
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'backup_progress',
          title: 'Keine Internetverbindung',
          body: 'Bitte prüfen Sie Ihre Verbindung',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      return;
    }
    debugPrint('Internet connection confirmed');

    // Benachrichtigungen initialisieren
    await initNotifications();

    bool backupSuccess = true;
    // Backup nur durchführen, wenn die Option aktiviert ist
    if (Options().backupBeforeSync) {
      debugPrint('Starting backup process...');
      showToast('Backup wird erstellt...');

      // Benachrichtigung anzeigen, dass Backup gestartet wird
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'backup_progress',
          title: 'Backup wird erstellt',
          body: 'Der Backup-Prozess wird gestartet...',
          notificationLayout: NotificationLayout.Default,
        ),
      );

      try {
        updater?.setDetailedProgress(
          overallProgress: 0.0,
          success: null,
          inspectionId: '',
          inspProgress: 0.0,
          etaString: '',
        );
      } catch (e) {
        debugPrint('Could not reset progress: $e');
      }

      backupSuccess = await _performBackup(updater);
    }

    // Nur wenn Backup erfolgreich war oder übersprungen wurde, Sync starten
    if (backupSuccess) {
      debugPrint('Starting sync process...');
      showToast('Synchronisierung wird gestartet...');
      bool success = await FailedRequestmanager().retryFailedrequests(
        context: context,
        onProgress: (overall, maybeSuccess, inspId, inspProg, etaStr) async {
          debugPrint(
              'Sync progress: ${(overall * 100).toStringAsFixed(1)}% - Current inspection: $inspId');

          // Extrahiere PJNr aus dem Request
          String? pjNr = inspId;
          try {
            if (inspId != 'Backup') {
              final failedReqs = await API().local.getAllFailedRequests();
              if (failedReqs != null) {
                for (var (_, requestData) in failedReqs) {
                  if (requestData != null) {
                    final jsonData = requestData.json;
                    if (jsonData != null) {
                      final data = jsonData['data'];
                      Map<String, dynamic> parsedData;

                      if (data is String) {
                        parsedData =
                            Map<String, dynamic>.from(json.decode(data));
                      } else if (data is Map<String, dynamic>) {
                        parsedData = data;
                      } else {
                        continue;
                      }

                      final localId = parsedData['local_id']?.toString();
                      if (localId == inspId) {
                        pjNr = parsedData['PjNr']?.toString();
                        break;
                      }
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error extracting PJNr: $e');
          }

          inspectionData.updateProgress(pjNr, inspProg);

          if (maybeSuccess == true && inspProg >= 1.0) {
            inspectionData.markAsCompleted(pjNr);
          }

          try {
            updater?.setDetailedProgress(
              overallProgress: overall,
              success: maybeSuccess,
              inspectionId: pjNr ?? inspId,
              inspProgress: inspProg,
              etaString: etaStr,
            );
          } catch (e) {
            debugPrint('Could not update sync progress: $e');
          }
        },
      );
      debugPrint('Sync finished: $success');
      await _checkSyncStatus();
      if (success) {
        showToast('Synchronisierung erfolgreich abgeschlossen');
      } else {
        showToast('Synchronisierung fehlgeschlagen');
      }
    }
  }

  Future<bool> _performBackup(ExtendedProgressStateUpdater? updater) async {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      showToast('Could not get external directory');
      return false;
    }

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
      await upsn.setProgress(0.0);

      // Prüfe Benachrichtigungsberechtigung
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        debugPrint(
            'Benachrichtigungen sind nicht erlaubt, fordere Berechtigung an...');
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      await for (BackupProgress progressValue in backup(backupPath)) {
        debugPrint(
            'Backup progress: ${(progressValue.progress * 100).toStringAsFixed(1)}%');
        await upsn.setBackupProgress(progressValue);
        try {
          updater?.setDetailedProgress(
            overallProgress: progressValue.progress,
            success: null,
            inspectionId: 'Backup',
            inspProgress: progressValue.progress,
            etaString: '',
          );
        } catch (e) {
          debugPrint('Could not update progress: $e');
        }

        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 1,
              channelKey:
                  'progress', // Verwende den lautlosen Kanal statt backup_progress
              title: 'Backup wird erstellt',
              body:
                  '${(progressValue.progress * 100).toStringAsFixed(1)}% - ${progressValue.currentFile}',
              notificationLayout: NotificationLayout.Default,
              progress: progressValue.progress,
            ),
          );
        } catch (e) {
          debugPrint('Fehler beim Senden der Benachrichtigung: $e');
        }
      }
      debugPrint('Backup completed successfully');
      upsn.setLoading(false);
      upsn.setSuccess(true);
      showToast('Backup erfolgreich erstellt');

      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey:
                'progress', // Verwende den lautlosen Kanal statt backup_progress
            title: 'Backup erfolgreich',
            body: 'Das Backup wurde erfolgreich erstellt',
            notificationLayout: NotificationLayout.Default,
          ),
        );
      } catch (e) {
        debugPrint('Fehler beim Senden der Benachrichtigung: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Backup failed: $e');
      showToast('Backup fehlgeschlagen');

      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey:
                'progress', // Verwende den lautlosen Kanal statt backup_progress
            title: 'Backup fehlgeschlagen',
            body: 'Es gab einen Fehler beim Erstellen des Backups',
            notificationLayout: NotificationLayout.Default,
          ),
        );
      } catch (e) {
        debugPrint('Fehler beim Senden der Benachrichtigung: $e');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final updater = context.watch<ExtendedProgressStateUpdater>();
    final inspectionData = context.watch<InspectionData>();
    final loading = updater.loading;
    final progress = updater.progress ?? 0.0;
    final success = updater.success;
    final inspId = updater.currentInspection ?? '';
    final inspPct = ((updater.currentInspectionProgress ?? 0) * 100).round();
    final eta = updater.eta ?? '';

    debugPrint(
        'Build: isAnalyzing=${inspectionData.isAnalyzing}, analyzedInspections=${inspectionData.analyzedInspections?.length ?? 0}');

    String tileText = '';
    if (loading) {
      if (inspId == 'Backup') {
        tileText = 'Backup wird\nerstellt';
      } else {
        tileText = 'Fortschritt:';
      }
    } else {
      tileText =
          isSynced ? 'Alles synchronisiert' : 'Synchronisierung\nmit Server';
    }

    return Column(
      children: [
        MyCardListTile1(
          icon: Icons.sync,
          text: tileText,
          onTap: onPress,
          child: loading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(width: 4),
                    Text(
                      '${(progress * 100).floor()}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 4),
                    SizedBox(
                      height: 25,
                      width: 25,
                      child: CircularProgressIndicator(
                        value: progress,
                      ),
                    ),
                  ],
                )
              : (isSynced
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : (success != null
                      ? Icon(
                          success ? Icons.check : Icons.error,
                          color: success ? Colors.green : Colors.red,
                        )
                      : null)),
        ),
        if (inspectionData.isAnalyzing)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text('Analysiere Requests...'),
              ],
            ),
          ),
        if (inspectionData.analyzedInspections != null)
          Container(
            height: 300,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    if (inspectionData.analyzedInspections!.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Keine ausstehenden Requests gefunden',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Abgeschlossene Inspektionen
                          if (inspectionData
                              .completedInspections.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Abgeschlossene Inspektionen',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            ...inspectionData.analyzedInspections!
                                .where((inspection) => inspectionData
                                    .completedInspections
                                    .contains(inspection.pjNr))
                                .map((inspection) => Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'PJNr: ${inspection.pjNr}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Icon(Icons.check_circle,
                                                    color: Colors.green),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            LinearProgressIndicator(
                                              value: 1.0,
                                              backgroundColor: Colors.grey[200],
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.green),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                                '${inspection.total} Requests'),
                                            Text(
                                                'Letzte Änderung: ${inspection.formattedLastModified}'),
                                            SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              children: inspection
                                                  .requestTypes.entries
                                                  .map((type) {
                                                return Chip(
                                                  label: Text(
                                                      '${type.key}: ${type.value}'),
                                                  backgroundColor:
                                                      Colors.grey[200],
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                          ],

                          // Laufende Inspektionen
                          if (inspectionData.analyzedInspections!.any(
                              (inspection) => !inspectionData
                                  .completedInspections
                                  .contains(inspection.pjNr))) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Laufende Inspektionen',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            ...inspectionData.analyzedInspections!
                                .where((inspection) => !inspectionData
                                    .completedInspections
                                    .contains(inspection.pjNr))
                                .map((inspection) {
                              final currentProgress = inspectionData
                                      .inspectionProgress[inspection.pjNr] ??
                                  inspection.progress;
                              final isCompleted = inspectionData
                                  .completedInspections
                                  .contains(inspection.pjNr);
                              final currentRequest =
                                  (inspection.total * currentProgress).round();

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'PJNr: ${inspection.pjNr}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            'Request $currentRequest von ${inspection.total}',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: currentProgress,
                                        backgroundColor: Colors.grey[200],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                          'Letzte Änderung: ${inspection.formattedLastModified}'),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
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

// Notification-Konfiguration
@pragma('vm:entry-point')
Future<void> _onActionReceivedMethod(ReceivedAction receivedAction) async {
  // Hier können wir auf Notification-Aktionen reagieren
}

@pragma('vm:entry-point')
Future<void> _onNotificationCreatedMethod(
    ReceivedNotification receivedNotification) async {
  // Hier können wir auf Notification-Erstellung reagieren
}

Future<void> initNotifications() async {
  // Wir stellen nur sicher, dass die Listener gesetzt sind
  // Die Kanäle wurden bereits beim App-Start in NotificationController initialisiert
  await AwesomeNotifications().setListeners(
    onActionReceivedMethod: _onActionReceivedMethod,
    onNotificationCreatedMethod: _onNotificationCreatedMethod,
  );
}

Future<void> reinitializeNotificationChannels() async {
  debugPrint(
      'Neuinitialisierung der Benachrichtigungskanäle für die Synchronisierung...');

  // Prüfe zuerst, ob Benachrichtigungen erlaubt sind
  final isAllowed = await AwesomeNotifications().isNotificationAllowed();
  if (!isAllowed) {
    debugPrint(
        'Benachrichtigungen sind nicht erlaubt, fordere Berechtigung an...');
    final requestResult =
        await AwesomeNotifications().requestPermissionToSendNotifications();
    if (!requestResult) {
      debugPrint('Benachrichtigungen wurden abgelehnt!');
      return;
    }
    debugPrint('Benachrichtigungen wurden erlaubt!');
  }

  try {
    // Lösche alle vorhandenen Kanäle
    await AwesomeNotifications().removeChannel('progress');
    await AwesomeNotifications().removeChannel('backup_progress');
    await AwesomeNotifications().removeChannel('sync_complete');

    // Füge Kanäle neu hinzu mit expliziten Einstellungen
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_icon',
      [
        NotificationChannel(
          channelGroupKey: 'mbg_retryfailed_group',
          channelKey: 'progress',
          channelName: 'Sync Fortschritt (LAUTLOS)',
          channelDescription: 'Zeigt den Fortschritt der Synchronisation an',
          defaultColor: Colors.blue,
          importance: NotificationImportance.Min,
          playSound: false,
          enableVibration: false,
          ledColor: Colors.transparent,
        ),
        NotificationChannel(
          channelGroupKey: 'mbg_retryfailed_group',
          channelKey: 'backup_progress',
          channelName: 'Backup Fortschritt (LAUTLOS)',
          channelDescription: 'Zeigt den Fortschritt des Backup-Prozesses an',
          defaultColor: Colors.blue,
          importance: NotificationImportance.Min,
          playSound: false,
          enableVibration: false,
          ledColor: Colors.transparent,
        ),
        NotificationChannel(
          channelGroupKey: 'mbg_retryfailed_group',
          channelKey: 'sync_complete',
          channelName: 'Sync Abschluss (MIT TON)',
          channelDescription:
              'Benachrichtigt über den Abschluss der Synchronisation',
          defaultColor: Colors.green,
          importance: NotificationImportance.High,
          playSound: true,
          enableVibration: true,
          ledColor: Colors.green,
        ),
      ],
    );

    debugPrint('Benachrichtigungskanäle wurden neu initialisiert');

    // Teste die Kanäle mit einer Benachrichtigung
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'progress',
          title: 'Test',
          body: 'Benachrichtigungskanäle wurden initialisiert',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      debugPrint('Test-Benachrichtigung erfolgreich gesendet');
    } catch (e) {
      debugPrint('Fehler beim Senden der Test-Benachrichtigung: $e');
    }
  } catch (e) {
    debugPrint(
        'Fehler bei der Initialisierung der Benachrichtigungskanäle: $e');
  }
}
