import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
class SettingsView extends StatefulWidget {
  final BuildContext logoutcontext;
  const SettingsView({super.key, required this.logoutcontext});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _isSynced = false;
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _currentInspectionId = '';
  double _currentInspectionProgress = 0.0;
  String _etaString = '';
  Map<String, double> _inspectionProgress = {};
  Map<String, List<String>> _inspectionRequests = {};
  Set<String> _completedInspections = {};
  bool? success;

  Future<void> _logout() async {
    await Provider.of<LoginModel>(widget.logoutcontext, listen: false).logout();
    Navigator.popUntil(widget.logoutcontext, (route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    _loadFailedRequests();
  }

  Future<void> _loadFailedRequests() async {
    final manager = FailedRequestmanager();
    final groupedInspections = await manager.getGroupedFailedRequests();

    if (groupedInspections.isNotEmpty) {
      Map<String, double> progressMap = {};
      Map<String, List<String>> requestsMap = {};
      Set<String> completedInspections = {};

      for (var inspection in groupedInspections) {
        progressMap[inspection.pjNr] = inspection.progress;
        requestsMap[inspection.pjNr] = inspection.requests;

        if (inspection.progress >= 1.0) {
          completedInspections.add(inspection.pjNr);
        }
      }

      setState(() {
        _inspectionProgress = progressMap;
        _inspectionRequests = requestsMap;
        _completedInspections = completedInspections;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isSynced = false;
                _isSyncing = false;
                _syncProgress = 0.0;
                _currentInspectionId = '';
                _currentInspectionProgress = 0.0;
                _etaString = '';
                _inspectionProgress = {};
                _inspectionRequests = {};
                _completedInspections = {};
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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
              _buildSyncTile(),
              if (_inspectionProgress.isNotEmpty)
                Container(
                  height: 250,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          if (_completedInspections.isNotEmpty)
                            ExpansionTile(
                              title: Text(
                                  'Abgeschlossene Inspektionen (${_completedInspections.length})'),
                              children: _completedInspections
                                  .map((id) => ListTile(
                                        title: Text('PJNr: $id'),
                                        trailing: Icon(Icons.check_circle,
                                            color: Colors.green),
                                      ))
                                  .toList(),
                            ),
                          ..._inspectionProgress.entries
                              .where((entry) =>
                                  !_completedInspections.contains(entry.key))
                              .map((entry) => Card(
                                    child: ExpansionTile(
                                      title: Text('PJNr: ${entry.key}'),
                                      subtitle: LinearProgressIndicator(
                                          value: entry.value),
                                      trailing: Text(
                                          '${(entry.value * 100).floor()}%'),
                                      children: _inspectionRequests[entry.key]
                                              ?.map((route) => ListTile(
                                                    title: Text(route),
                                                    leading:
                                                        Icon(Icons.arrow_right),
                                                  ))
                                              .toList() ??
                                          [],
                                    ),
                                  )),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncTile() {
    return MyCardListTile1(
      icon: Icons.sync,
      text: _isSynced
          ? 'Offline Änderungen wurden synchronisiert'
          : 'Offline Änderungen synchronisieren',
      onTap: _isSyncing ? null : _syncOfflineChanges,
      child: _isSyncing
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(_syncProgress * 100).floor()}%',
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
                    value: _syncProgress,
                  ),
                ),
              ],
            )
          : (_isSynced
              ? Icon(Icons.check_circle, color: Colors.green)
              : (success == true
                  ? Icon(Icons.check, color: Colors.green)
                  : success == false
                      ? Icon(Icons.error, color: Colors.red)
                      : null)),
    );
  }

  Future<void> _syncOfflineChanges() async {
    setState(() {
      _isSyncing = true;
      _isSynced = false;
      _syncProgress = 0.0;
      _currentInspectionId = '';
      _currentInspectionProgress = 0.0;
      _etaString = '';
      _inspectionProgress = {};
      _inspectionRequests = {};
      _completedInspections = {};
    });

    // Lade sofort die fehlgeschlagenen Requests
    final failedReqs = await API().local.getAllFailedRequests() ?? [];
    if (failedReqs.isNotEmpty) {
      // Gruppiere Requests nach PJNr
      Map<String, List<String>> groupedRequests = {};
      for (var req in failedReqs) {
        try {
          final requestData = req as Map<String, dynamic>;
          final jsonData = requestData['json'] as Map<String, dynamic>;
          final data = jsonData['data'];
          Map<String, dynamic> parsedData;

          if (data is String) {
            parsedData = Map<String, dynamic>.from(json.decode(data));
          } else {
            parsedData = Map<String, dynamic>.from(data);
          }

          final pjNr = parsedData['PjNr']?.toString() ?? 'Unbekannt';

          if (!groupedRequests.containsKey(pjNr)) {
            groupedRequests[pjNr] = [];
          }
          groupedRequests[pjNr]!
              .add(requestData['route'] ?? 'Unbekannte Route');
        } catch (e) {
          debugPrint('Error parsing request: $e');
        }
      }

      // Initialisiere die Fortschrittsanzeige
      setState(() {
        _inspectionProgress = Map.fromEntries(
          groupedRequests.keys.map((key) => MapEntry(key, 0.0)),
        );
        _inspectionRequests = groupedRequests;
      });
    }

    // Starte den Upload-Prozess
    final manager = FailedRequestmanager();
    final result = await manager.retryFailedrequests(
      context: context,
      onProgress: (overallProgress, success, currentInspId, currentInspProgress,
          etaString) {
        setState(() {
          _syncProgress = overallProgress;
          _currentInspectionId = currentInspId ?? '';
          _currentInspectionProgress = currentInspProgress;
          _etaString = etaString;

          if (currentInspId != null && currentInspId.isNotEmpty) {
            _inspectionProgress[currentInspId] = currentInspProgress;
            if (currentInspProgress >= 1.0) {
              _completedInspections.add(currentInspId);
            }
          }

          if (success != null) {
            _isSyncing = false;
            _isSynced = success;
            this.success = success;
          }
        });
      },
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
  List<String?> completedInspections = [];
  Map<String?, double> inspectionProgress = {};
  Map<String?, List<String>> inspectionRequests = {};
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

  Future<void> onPress() async {
    if (isSynced) {
      showToast('Alle Inspektionen sind bereits synchronisiert');
      return;
    }

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

    // Gruppiere Requests nach PJNr
    Map<String, List<String>> groupedRequests = {};
    for (var req in failedReqs) {
      try {
        final requestData = req as Map<String, dynamic>;
        final jsonData = requestData['json'] as Map<String, dynamic>;
        final data = jsonData['data'];
        Map<String, dynamic> parsedData;

        if (data is String) {
          // Wenn data ein JSON-String ist, parsen wir ihn
          parsedData = Map<String, dynamic>.from(json.decode(data));
        } else {
          // Wenn data bereits ein Objekt ist, verwenden wir es direkt
          parsedData = Map<String, dynamic>.from(data);
        }

        final pjNr = parsedData['PjNr']?.toString() ?? 'Unbekannt';

        if (!groupedRequests.containsKey(pjNr)) {
          groupedRequests[pjNr] = [];
        }
        groupedRequests[pjNr]!.add(requestData['route'] ?? 'Unbekannte Route');
      } catch (e) {
        debugPrint('Error parsing request: $e');
      }
    }

    // Setze den initialen Zustand für die Anzeige
    setState(() {
      inspectionRequests = groupedRequests;
      completedInspections = [];
      inspectionProgress = {};
      showCompleted = false;
    });

    // Setze initialen Fortschritt für alle Inspektionen auf 0
    for (var pjNr in groupedRequests.keys) {
      inspectionProgress[pjNr] = 0.0;
    }

    // Warte, bis der State aktualisiert wurde
    await Future.delayed(const Duration(milliseconds: 100));

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
          category: NotificationCategory.Status,
          displayOnForeground: false,
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
                for (var req in failedReqs) {
                  final requestData = req as Map<String, dynamic>;
                  final jsonData = requestData['json'] as Map<String, dynamic>;
                  final dataStr = jsonData['data'] as String;
                  final data = Map<String, dynamic>.from(json.decode(dataStr));
                  final localId = data['local_id'] as String?;
                  if (localId == inspId) {
                    pjNr = data['PjNr']?.toString();
                    break;
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error extracting PJNr: $e');
          }

          setState(() {
            if (pjNr != null && pjNr != 'Backup') {
              inspectionProgress[pjNr] = inspProg;
              if (maybeSuccess == true) {
                completedInspections.add(pjNr);
              }
            }
          });

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

        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey: 'backup_progress',
            title: 'Backup wird erstellt',
            body:
                '${(progressValue.progress * 100).toStringAsFixed(1)}% - ${progressValue.currentFile}',
            notificationLayout: NotificationLayout.Default,
            progress: progressValue.progress,
          ),
        );
      }
      debugPrint('Backup completed successfully');
      upsn.setLoading(false);
      upsn.setSuccess(true);
      showToast('Backup erfolgreich erstellt');

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'backup_progress',
          title: 'Backup erfolgreich',
          body: 'Das Backup wurde erfolgreich erstellt',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Backup failed: $e');
      showToast('Backup fehlgeschlagen');

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1,
          channelKey: 'backup_progress',
          title: 'Backup fehlgeschlagen',
          body: 'Es gab einen Fehler beim Erstellen des Backups',
          notificationLayout: NotificationLayout.Default,
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final updater = context.watch<ExtendedProgressStateUpdater>();
    final loading = updater.loading;
    final progress = updater.progress ?? 0.0;
    final success = updater.success;
    final inspId = updater.currentInspection ?? '';
    final inspPct = ((updater.currentInspectionProgress ?? 0) * 100).round();
    final eta = updater.eta ?? '';

    String secondLine = '';
    if (loading) {
      if (inspId == 'Backup') {
        secondLine = 'Backup';
      } else if (inspId.isNotEmpty) {
        secondLine = 'Sync';
      }
    }

    final tileText = loading
        ? '${inspId == 'Backup' ? 'Schritt 1/2' : 'Schritt 2/2'}: \n$secondLine'
        : isSynced
            ? 'Alles synchronisiert'
            : 'Synchronisierung \n mit Server';

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
        if (inspectionProgress.isNotEmpty)
          Container(
            height: 300, // Feste Höhe für den scrollbaren Bereich
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    if (completedInspections.isNotEmpty)
                      ExpansionTile(
                        title: Text(
                            'Abgeschlossene Inspektionen (${completedInspections.length})'),
                        children: completedInspections
                            .map((id) => ListTile(
                                  title: Text('PJNr: $id'),
                                  trailing: Icon(Icons.check_circle,
                                      color: Colors.green),
                                ))
                            .toList(),
                      ),
                    ...inspectionProgress.entries
                        .where((entry) =>
                            !completedInspections.contains(entry.key))
                        .map((entry) => Card(
                              child: ExpansionTile(
                                title: Text('PJNr: ${entry.key}'),
                                subtitle:
                                    LinearProgressIndicator(value: entry.value),
                                trailing:
                                    Text('${(entry.value * 100).floor()}%'),
                                children: inspectionRequests[entry.key]
                                        ?.map((route) => ListTile(
                                              title: Text(route),
                                              leading: Icon(Icons.arrow_right),
                                            ))
                                        .toList() ??
                                    [],
                              ),
                            )),
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
  await AwesomeNotifications().initialize(
    'resource://drawable/ic_icon',
    [
      NotificationChannel(
        channelKey: 'backup_progress',
        channelName: 'Backup Fortschritt',
        channelDescription: 'Zeigt den Fortschritt des Backup-Prozesses an',
        importance: NotificationImportance.Low,
        defaultPrivacy: NotificationPrivacy.Private,
        defaultRingtoneType: DefaultRingtoneType.Notification,
        enableVibration: false,
        playSound: false,
      ),
    ],
  );

  await AwesomeNotifications().setListeners(
    onActionReceivedMethod: _onActionReceivedMethod,
    onNotificationCreatedMethod: _onNotificationCreatedMethod,
  );
}
