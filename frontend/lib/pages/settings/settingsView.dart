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
import 'package:device_info_plus/device_info_plus.dart';

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
    try {
      // Verwende den direkten Kontext statt widget.logoutcontext
      await Provider.of<LoginModel>(context, listen: false).logout();

      // Füge Verzögerung hinzu, um UI-Updates abzuschließen
      await Future.delayed(Duration(milliseconds: 100));

      // Lösche alle Routen im Stack und gehe zurück zur Login-Seite
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);

      // Debugausgabe für erfolgreichen Logout
      debugPrint('Logout erfolgreich, Navigation zur Login-Seite');
    } catch (e) {
      debugPrint('Fehler beim Logout: $e');
      // Fallback: Wenn der Navigator-Aufruf fehlschlägt, versuche einen alternativen Ansatz
      try {
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (navError) {
        debugPrint('Auch alternative Navigation fehlgeschlagen: $navError');
      }
    }
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
                NotificationSettingsTile(),
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
  // Für Android 13+ ist Permission.storage veraltet, daher nutzen wir direkt manageExternalStorage
  if (Platform.isAndroid) {
    try {
      // Prüfe Android-Version
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      debugPrint('Android SDK Version erkannt: $sdkInt');

      // Für neuere Android-Versionen (API 33+) verwenden wir manageExternalStorage
      if (sdkInt >= 33) {
        debugPrint('Verwende manageExternalStorage für Android 13+');

        var externalStatus = await Permission.manageExternalStorage.status;
        if (!externalStatus.isGranted) {
          debugPrint('Erweiterte Speicherberechtigung fehlt');

          // Die manageExternalStorage-Anfrage öffnet automatisch die spezifischen Systemeinstellungen
          final result = await Permission.manageExternalStorage.request();

          if (result.isGranted) {
            debugPrint('Externe Speicherberechtigung wurde gewährt');
            return true;
          } else {
            // Wenn die Berechtigung nicht erteilt wurde, zeigen wir einen Dialog
            final bool? shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Speicherzugriff erforderlich'),
                  content: Text(
                      'Für das Erstellen von Backups benötigt die App erweiterten Zugriff auf den Speicher. Bitte erlauben Sie den Zugriff in den Einstellungen.'),
                  actions: <Widget>[
                    TextButton(
                      child: Text('Abbrechen'),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    TextButton(
                      child: Text('Zu Einstellungen'),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
              },
            );

            if (shouldOpenSettings == true) {
              debugPrint(
                  'Öffne App-Einstellungen für erweiterte Speicherberechtigung...');
              await openAppSettings();

              // Kurz warten und nochmal prüfen
              await Future.delayed(Duration(seconds: 2));
              externalStatus = await Permission.manageExternalStorage.status;
              if (externalStatus.isGranted) {
                debugPrint('Externe Speicherberechtigung wurde erteilt');
                return true;
              } else {
                debugPrint(
                    'Externe Speicherberechtigung immer noch nicht erlaubt');
                return false;
              }
            } else {
              debugPrint('Benutzer hat abgebrochen');
              return false;
            }
          }
        } else {
          debugPrint('Externe Speicherberechtigung bereits erteilt');
          return true;
        }
      }
      // Für Android 10-12 (API 29-32) einen Mix aus beiden Berechtigungen versuchen
      else if (sdkInt >= 29) {
        debugPrint('Verwende dual Berechtigung für Android 10-12');

        // Zuerst manageExternalStorage versuchen
        try {
          var externalStatus = await Permission.manageExternalStorage.status;
          if (!externalStatus.isGranted) {
            final result = await Permission.manageExternalStorage.request();
            if (result.isGranted) {
              debugPrint('Externe Speicherberechtigung wurde gewährt');
              return true;
            }
          } else {
            return true;
          }
        } catch (e) {
          debugPrint('Fehler bei manageExternalStorage: $e');
        }

        // Als Fallback storage versuchen
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (result.isGranted) {
            debugPrint('Normale Speicherberechtigung wurde gewährt');
            return true;
          } else {
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
              await openAppSettings();
              await Future.delayed(Duration(seconds: 2));
              status = await Permission.storage.status;
              if (status.isGranted) {
                return true;
              } else {
                return false;
              }
            } else {
              return false;
            }
          }
        } else {
          return true;
        }
      }
      // Für alte Android-Versionen (API < 29) nur storage verwenden
      else {
        debugPrint('Verwende storage Berechtigung für Android 9 oder älter');

        var status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          if (result.isGranted) {
            debugPrint('Speicherberechtigung wurde gewährt');
            return true;
          } else {
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
              await openAppSettings();
              await Future.delayed(Duration(seconds: 2));
              status = await Permission.storage.status;
              if (status.isGranted) {
                debugPrint('Speicherberechtigung wurde erteilt');
                return true;
              } else {
                debugPrint('Speicherberechtigung immer noch nicht erlaubt');
                return false;
              }
            } else {
              return false;
            }
          }
        } else {
          return true;
        }
      }
    } catch (e) {
      debugPrint('Fehler bei der Prüfung der Android-Version: $e');
      // Bei Fehler in der Versionserkennung als Fallback storage verwenden
      try {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          final result = await Permission.storage.request();
          return result.isGranted;
        }
        return true;
      } catch (e) {
        debugPrint('Auch Fallback fehlgeschlagen: $e');
        return false;
      }
    }
  }
  // Für iOS keine spezielle Behandlung
  else if (Platform.isIOS) {
    return true;
  }

  // Für alle anderen Plattformen
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

  // Eine private Version der _performBackup Methode für die BackupTile
  Future<bool> _performLocalBackup(BuildContext context) async {
    // Prüfe zuerst die Berechtigungen, bevor wir irgendetwas anderes tun
    if (!await _requestStoragePermission(context)) {
      showToast('Speicherberechtigung ist erforderlich für das Backup');
      return false;
    }

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

      debugPrint('Starte Backup nach: $backupPath');

      // Fortschrittsstream abonnieren und UI aktualisieren
      await for (BackupProgress progressValue in backup(backupPath)) {
        // Regelmäßiges Aktualisieren der UI garantieren
        if (mounted) {
          setState(() {
            progress = progressValue.progress;
            currentFile = progressValue.currentFile;
            eta = progressValue.eta;
          });
        }

        // Sende Fortschrittsbenachrichtigung alle 10%
        if (progressValue.progress * 100 % 10 < 0.5) {
          try {
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: 20,
                channelKey: 'mbg_all_notifications',
                title: 'Backup Fortschritt',
                body:
                    '${(progressValue.progress * 100).toStringAsFixed(1)}% - ${progressValue.currentFile}',
                notificationLayout: NotificationLayout.ProgressBar,
                progress: progressValue.progress,
                autoDismissible: true,
              ),
            );
          } catch (e) {
            debugPrint(
                'Fehler beim Senden der Fortschrittsbenachrichtigung: $e');
            // Fehler ignorieren und weitermachen
          }
        }

        // Debug-Ausgabe für Fortschritt
        if (progressValue.progress * 100 % 5 < 0.1) {
          // Nur alle 5% loggen
          debugPrint(
              'Backup Fortschritt: ${(progressValue.progress * 100).toStringAsFixed(1)}% - ETA: ${progressValue.eta}');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Fehler beim Backup-Erstellen: $e');
      return false;
    }
  }

  void onPress(BuildContext context) async {
    // Prüfe zuerst die Berechtigungen, bevor wir irgendetwas anderes tun
    if (!await _requestStoragePermission(context)) {
      showToast('Speicherberechtigung ist erforderlich für das Backup');
      return;
    }

    // Benachrichtigungen initialisieren
    await initNotifications();

    setState(() {
      loading = true;
      progress = 0.0;
      success = null;
      currentFile = '';
      eta = '';
    });

    try {
      // Benachrichtigung direkt am Anfang senden
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey: 'mbg_all_notifications',
            title: 'Backup wird erstellt',
            body: 'Der Backup-Prozess wird gestartet...',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: true,
          ),
        );
      } catch (e) {
        debugPrint('Fehler beim Senden der Start-Benachrichtigung: $e');
        // Trotzdem fortfahren
      }

      // Führe das Backup durch
      final backupSuccess = await _performLocalBackup(context);

      if (mounted) {
        setState(() {
          success = backupSuccess;
          loading = false;
        });
      }

      if (backupSuccess) {
        // Sende Erfolgsbenachrichtigung
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 30,
              channelKey: 'mbg_all_notifications',
              title: 'Backup abgeschlossen',
              body: 'Das Backup wurde erfolgreich erstellt',
              notificationLayout: NotificationLayout.Default,
              autoDismissible: true,
            ),
          );
        } catch (e) {
          debugPrint('Fehler beim Senden der Erfolgsbenachrichtigung: $e');
        }

        // Teile das Backup
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final backupDir = Directory('${externalDir.parent.path}/MBGBackups');
          final backupPath =
              '${backupDir.path}/backup-${DateTime.now().millisecondsSinceEpoch}.zip';

          showToast('Local backup finished at: $backupPath');
          debugPrint('Backup erfolgreich abgeschlossen');

          Share.shareXFiles(
            [XFile(backupPath)],
            text: 'Backup from MBG Inspektionen',
            subject: 'Backup from MBG Inspektionen',
          );
        }
      } else {
        // Sende Fehlerbenachrichtigung
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 40,
              channelKey: 'mbg_all_notifications',
              title: 'Backup fehlgeschlagen',
              body: 'Das Backup konnte nicht erstellt werden',
              notificationLayout: NotificationLayout.Default,
              autoDismissible: true,
            ),
          );
        } catch (e) {
          debugPrint('Fehler beim Senden der Fehlerbenachrichtigung: $e');
        }

        showToast('Could not create backup');
      }
    } catch (e) {
      debugPrint('Fehler beim Backup-Erstellen: $e');
      if (mounted) {
        setState(() {
          success = false;
          loading = false;
        });
      }

      // Sende Fehlerbenachrichtigung
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 40,
            channelKey: 'mbg_all_notifications',
            title: 'Backup fehlgeschlagen',
            body: 'Das Backup konnte nicht erstellt werden: $e',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: true,
          ),
        );
      } catch (notifyError) {
        debugPrint(
            'Fehler beim Senden der Fehlerbenachrichtigung: $notifyError');
      }

      showToast('Could not create backup');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Verbesserte Formatierung für den Fortschritt
    String tileText;
    if (loading) {
      final percent = (progress * 100).floor();
      final etaText = eta.isNotEmpty ? 'ETA: $eta' : '';
      final fileName = currentFile.isNotEmpty
          ? (currentFile.length > 25
              ? '...${currentFile.substring(currentFile.length - 25)}'
              : currentFile)
          : '';

      tileText = '$percent% Backup läuft\n$fileName\n$etaText';
    } else {
      tileText = 'Backup';
    }

    return MyCardListTile1(
      icon: Icons.folder_zip,
      text: tileText,
      onTap: () => onPress(context),
      child: loading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(progress * 100).floor()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 25,
                  width: 25,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                  ),
                ),
              ],
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
          channelKey: 'mbg_all_notifications',
          title: 'Keine Internetverbindung',
          body: 'Bitte prüfen Sie Ihre Verbindung',
          notificationLayout: NotificationLayout.Default,
          autoDismissible: true,
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

      // Zuerst Speicherberechtigung prüfen, bevor das Backup gestartet wird
      if (!await _requestStoragePermission(context)) {
        showToast('Speicherberechtigung ist erforderlich für das Backup');
        // Trotzdem mit Synchronisierung fortfahren, aber ohne Backup
        debugPrint(
            'Starte Synchronisierung ohne Backup, da Speicherberechtigung fehlt');
      } else {
        // Benachrichtigung anzeigen, dass Backup gestartet wird
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey: 'mbg_all_notifications',
            title: 'Backup wird erstellt',
            body: 'Der Backup-Prozess wird gestartet...',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: true,
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

        backupSuccess = await _performBackup(updater, context);
      }
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

  Future<bool> _performBackup(
      ExtendedProgressStateUpdater? updater, BuildContext context) async {
    // Zusätzliche Sicherheit: Prüfe die Speicherberechtigung auch hier
    if (!await _requestStoragePermission(context)) {
      showToast('Speicherberechtigung ist erforderlich für das Backup');
      return false;
    }

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

        // Prüfe, ob updater nicht null und nicht disposed ist
        if (updater != null) {
          try {
            updater.setDetailedProgress(
              overallProgress: progressValue.progress,
              success: null,
              inspectionId: 'Backup',
              inspProgress: progressValue.progress,
              etaString: '',
            );
          } catch (e) {
            debugPrint('Could not update progress: $e');
            // Kein Abbruch wegen UI-Fehler, Backup soll weiterlaufen
          }
        }

        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 1,
              channelKey: 'mbg_all_notifications',
              title: 'Backup wird erstellt',
              body:
                  '${(progressValue.progress * 100).toStringAsFixed(1)}% - ${progressValue.currentFile}',
              notificationLayout: NotificationLayout.Default,
              progress: progressValue.progress,
              autoDismissible: true,
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
            channelKey: 'mbg_all_notifications',
            title: 'Backup erfolgreich',
            body: 'Das Backup wurde erfolgreich erstellt',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: true,
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
            channelKey: 'mbg_all_notifications',
            title: 'Backup fehlgeschlagen',
            body: 'Es gab einen Fehler beim Erstellen des Backups',
            notificationLayout: NotificationLayout.Default,
            autoDismissible: true,
          ),
        );
      } catch (e) {
        //debugPrint('Fehler beim Senden der Benachrichtigung: $e');
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

    ////debugPrint(
       // 'Build: isAnalyzing=${inspectionData.isAnalyzing}, analyzedInspections=${inspectionData.analyzedInspections?.length ?? 0}');

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
  try {
    // Listener setzen
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
      onNotificationCreatedMethod: _onNotificationCreatedMethod,
    );

    // Prüfen ob Benachrichtigungen erlaubt sind
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      debugPrint(
          'Benachrichtigungen sind nicht erlaubt, fordere Berechtigung an...');
      final requestResult =
          await AwesomeNotifications().requestPermissionToSendNotifications();

      if (requestResult) {
        debugPrint('Benachrichtigungen wurden erlaubt!');
        // Nach der Erlaubnis Kanäle neu initialisieren
        await reinitializeNotificationChannels();
      } else {
        debugPrint('Benachrichtigungen wurden abgelehnt');
      }
    } else {
      debugPrint('Benachrichtigungen sind bereits erlaubt');
      // Auch wenn sie bereits erlaubt sind, Kanäle neu initialisieren
      await reinitializeNotificationChannels();
    }
  } catch (e) {
    debugPrint('Fehler beim Initialisieren der Benachrichtigungen: $e');
  }
}

Future<void> reinitializeNotificationChannels() async {
  debugPrint('Initialisiere alle Benachrichtigungskanäle...');

  try {
    // Zuerst alle vorhandenen Kanäle entfernen
    await AwesomeNotifications()
        .cancelAll(); // Alle aktiven Benachrichtigungen löschen

    // Standard-Kanäle direkt entfernen
    try {
      await AwesomeNotifications().removeChannel('progress');
      await AwesomeNotifications().removeChannel('backup_progress');
      await AwesomeNotifications().removeChannel('sync_complete');
      debugPrint('Standard-Kanäle entfernt');
    } catch (e) {
      debugPrint('Fehler beim Entfernen der Standard-Kanäle: $e');
    }

    // Warte kurz, um sicherzustellen, dass die Kanäle wirklich entfernt wurden
    await Future.delayed(const Duration(milliseconds: 500));

    // WICHTIG: Alle Kanäle in einen einzigen Hauptkanal konsolidieren
    // Dies kann auf manchen Android-Geräten die Aktivierung erleichtern
    await AwesomeNotifications().initialize(
      'resource://drawable/ic_icon',
      [
        NotificationChannel(
          channelKey:
              'mbg_all_notifications', // Ein Hauptkanal für alle Benachrichtigungen
          channelName: 'MBG App Benachrichtigungen',
          channelDescription: 'Alle Benachrichtigungen der MBG App',
          defaultColor: Colors.blue,
          importance:
              NotificationImportance.Max, // Maximale Priorität für Sichtbarkeit
          playSound: true, // Sound einschalten für bessere Erkennung
          enableVibration: true, // Vibration für bessere Erkennung
          ledColor: Colors.blue,
          // Keine Gruppierung mehr, da dies auf manchen Geräten Probleme verursachen kann
        ),
      ],
    );

    // Eine kurze Verzögerung
    await Future.delayed(const Duration(milliseconds: 500));

    // Eine aktive Benachrichtigung senden und NICHT sofort löschen
    // Dies ist wichtig, damit der Benutzer sie sehen und mit ihr interagieren kann
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1000,
        channelKey: 'mbg_all_notifications',
        title: 'Benachrichtigungen aktiviert',
        body:
            'Die App kann jetzt Benachrichtigungen anzeigen. Tippe hier, um Einstellungen zu öffnen.',
        notificationLayout: NotificationLayout.Default,
        payload: {'open_settings': 'true'},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'OPEN_SETTINGS',
          label: 'Einstellungen öffnen',
          enabled: true,
        ),
      ],
    );

    debugPrint('Benachrichtigungskanal erfolgreich initialisiert');
  } catch (e) {
    debugPrint(
        'Fehler bei der Initialisierung des Benachrichtigungskanals: $e');
  }
}

// Vereinfachen für die Anzeige während der Backup-Erstellung
Future<void> sendBackupProgressNotification(
    double progress, String currentFile) async {
  try {
    // WICHTIG: Verwende den gemeinsamen Kanal
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 10,
        channelKey: 'mbg_all_notifications',
        title: 'Backup wird erstellt',
        body: 'Fortschritt: ${(progress * 100).round()}% - $currentFile',
        notificationLayout: NotificationLayout.ProgressBar,
        progress: progress,
      ),
    );
  } catch (e) {
    debugPrint(
        'Fehler beim Senden der Backup-Fortschrittsbenachrichtigung: $e');
  }
}

// Vereinfachen für die Anzeige während der Synchronisierung
Future<void> sendSyncProgressNotification(
    double progress, String currentInspection) async {
  try {
    // WICHTIG: Verwende den gemeinsamen Kanal
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 20,
        channelKey: 'mbg_all_notifications',
        title: 'Synchronisierung läuft',
        body: 'Fortschritt: ${(progress * 100).round()}% - $currentInspection',
        notificationLayout: NotificationLayout.ProgressBar,
        progress: progress,
      ),
    );
  } catch (e) {
    debugPrint('Fehler beim Senden der Sync-Fortschrittsbenachrichtigung: $e');
  }
}

// Benachrichtigungskachel für die Einstellungen
class NotificationSettingsTile extends StatelessWidget {
  const NotificationSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return MyCardListTile1(
      icon: Icons.notifications,
      text: 'Benachrichtigungen verwalten',
      onTap: () async {
        final isAllowed = await AwesomeNotifications().isNotificationAllowed();
        if (isAllowed) {
          openNotificationSettings();
        } else {
          showNotificationPermissionDialog(context);
        }
      },
      child: FutureBuilder<bool>(
        future: AwesomeNotifications().isNotificationAllowed(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2));
          }

          final isAllowed = snapshot.data ?? false;
          return Icon(
            isAllowed ? Icons.notifications_active : Icons.notifications_off,
            color: isAllowed ? Colors.green : Colors.red,
          );
        },
      ),
    );
  }
}

// Funktion zum Öffnen der Benachrichtigungseinstellungen
Future<void> openNotificationSettings() async {
  try {
    await AwesomeNotifications().showNotificationConfigPage();
    debugPrint('Benachrichtigungseinstellungen geöffnet');
  } catch (e) {
    debugPrint('Fehler beim Öffnen der Benachrichtigungseinstellungen: $e');
    // Fallback: App-Einstellungen öffnen
    await openAppSettings();
  }
}

// Dialog zum Aktivieren der Benachrichtigungen anzeigen
Future<void> showNotificationPermissionDialog(BuildContext context) async {
  final shouldRequest = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Benachrichtigungen erlauben'),
      content: Text(
          'Diese App benötigt Benachrichtigungen für Fortschrittsinformationen und Abschlüsse. Bitte aktiviere die Benachrichtigungen in den Einstellungen.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Aktivieren'),
        ),
      ],
    ),
  );

  if (shouldRequest == true) {
    final granted =
        await AwesomeNotifications().requestPermissionToSendNotifications();
    if (granted) {
      await reinitializeNotificationChannels();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Benachrichtigungen wurden aktiviert')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Bitte erlaube Benachrichtigungen in den Einstellungen')),
      );
      await openAppSettings();
    }
  }
}
