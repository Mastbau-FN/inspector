import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart';

import 'package:MBG_Inspektionen/helpers/background.dart' as BG;
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/backend/helpers.dart' as Helper;
import 'package:flutter/services.dart';

import '../notifications/controller.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';

import 'package:MBG_Inspektionen/options.dart';

// Diese drei Konstanten nur hier zentral definieren.
// Von hier aus werden sie dann auch in anderen Dateien importiert.
final sync_progress_str = 'sync progress';
final sync_in_progress_str = 'sync in progress';
final sync_success_str = 'sync success';

/// Hilfsklasse, um globale und Inspektions-spezifische Upload-Fortschritte
/// samt ETA zu verwalten.
class SyncProgress {
  final int totalRequests;
  int doneRequests = 0;

  // Aktuelle Inspektion
  String currentInspectionId = '';
  int currentInspectionTotal = 0;
  int currentInspectionDone = 0;

  // Für ETA
  DateTime startTime = DateTime.now();
  double averageTimePerRequest = 0;
  int _accumulatedDurationMs = 0;
  int _requestCount = 0;

  SyncProgress(this.totalRequests) {
    // debugPrint('SyncProgress initialisiert mit $totalRequests Requests');
  }

  double get overallProgress {
    if (totalRequests == 0) return 1.0;
    final progress = doneRequests / totalRequests;
    // debugPrint('Fortschritt: $doneRequests von $totalRequests Requests = ${(progress * 100).toStringAsFixed(1)}%');
    return progress;
  }

  double get currentInspectionProgress {
    if (currentInspectionTotal == 0) return 1.0;
    return currentInspectionDone / currentInspectionTotal;
  }

  Duration get estimatedTimeRemaining {
    final remaining = totalRequests - doneRequests;
    if (remaining <= 0 || averageTimePerRequest <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (averageTimePerRequest * remaining).round());
  }

  void updateTiming(Duration singleRequest) {
    _accumulatedDurationMs += singleRequest.inMilliseconds;
    _requestCount++;
    averageTimePerRequest = _accumulatedDurationMs / _requestCount;
  }
}

/// Aus dem JSON String in rd.json['data'] wird die local_id (oder PjNr) geholt.
String _extractInspectionIdFromRequest(RequestData rd) {
  try {
    final dataField = rd.json?['data'];
    if (dataField == null) return 'unknown';

    Map<String, dynamic> parsedData;
    if (dataField is String) {
      parsedData = Map<String, dynamic>.from(json.decode(dataField));
    } else if (dataField is Map<String, dynamic>) {
      parsedData = dataField;
    } else {
      return 'unknown';
    }

    // Versuche zuerst die PjNr zu extrahieren
    final pjNr = parsedData['PjNr']?.toString();
    if (pjNr != null && pjNr.isNotEmpty) {
      return pjNr;
    }

    // Fallback: local_id
    final localId = parsedData['local_id']?.toString();
    if (localId != null && localId.isNotEmpty) {
      return localId;
    }
  } catch (e) {
    // debugPrint('Could not parse inspectionId: $e');
  }
  return 'unknown';
}

/// Gruppiert die Requests nach extrahierter Inspection-ID, anschließend sortiert.
Map<String, List<(String docID, RequestData?)>> _groupRequestsByInspection(
  List<(String, RequestData?)> failedReqs,
) {
  final Map<String, List<(String, RequestData?)>> grouped = {};

  for (final (docID, rd) in failedReqs) {
    if (rd == null) continue;
    final inspId = _extractInspectionIdFromRequest(rd);
    grouped.putIfAbsent(inspId, () => []);
    grouped[inspId]!.add((docID, rd));
  }

  // Sortiere Keys alphabetisch
  final sortedKeys = grouped.keys.toList()..sort();
  final sortedMap = <String, List<(String, RequestData?)>>{};
  for (final k in sortedKeys) {
    sortedMap[k] = grouped[k]!;
  }
  return sortedMap;
}

/// Formatiert Duration zu einem kurzen String.
String _formatDuration(Duration d) {
  if (d.inMinutes >= 1) {
    return '${d.inMinutes} min';
  }
  return '${d.inSeconds} s';
}

/// Prüft, ob Benachrichtigungen erlaubt sind und fragt bei Bedarf
Future<bool> _ensureNotificationsAllowed() async {
  try {
    // Prüfe, ob Benachrichtigungen erlaubt sind
    final isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      // debugPrint('Benachrichtigungen sind nicht erlaubt, fordere an...');

      // Fordere Benachrichtigungsberechtigung an
      final requestResult =
          await AwesomeNotifications().requestPermissionToSendNotifications();

      if (requestResult) {
        // debugPrint('Benachrichtigungen wurden erlaubt!');
        return true;
      } else {
        // debugPrint('Benachrichtigungen wurden abgelehnt!');
        return false;
      }
    }
    return true;
  } catch (e) {
    // debugPrint('Fehler bei Benachrichtigungsprüfung: $e');
    return false;
  }
}

/// Aktualisiert die laufende Sync-Notification (immer selbe ID => fortlaufendes Update).
Future<void> _updateSyncNotification({
  required SyncProgress progress,
  required bool successSoFar,
  String? pjNr,
}) async {
  // Prüfe zuerst, ob Benachrichtigungen erlaubt sind
  if (!await _ensureNotificationsAllowed()) {
    // debugPrint('Benachrichtigungen sind nicht erlaubt, überspringe Notification');
    return;
  }

  final overallPct = (progress.overallProgress * 100).round().toDouble();
  final inspPct = (progress.currentInspectionProgress * 100).round();
  final etaStr = _formatDuration(progress.estimatedTimeRemaining);

  final title = successSoFar ? 'Upload Sync läuft...' : 'Upload Sync (Fehler)';

  // Verwende explizite Trennlinien für bessere visuelle Trennung
  final body = 'Inspektion: ${pjNr ?? progress.currentInspectionId}\n'
      '------------------------\n'
      'Inspektions-Fortschritt: $inspPct%\n'
      '------------------------\n'
      'Gesamt-Fortschritt: $overallPct%\n'
      '------------------------\n'
      'Verbleibende Zeit: ~ $etaStr';

  // debugPrint('Sende Benachrichtigung: Gesamtfortschritt: $overallPct%, Inspektionsfortschritt: $inspPct%, BenutzeKanal: PROGRESS');

  try {
    // Verwende immer den 'progress' Kanal für Zwischenmeldungen (lautlos)
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 888, // Verwende eine andere ID als die abschließenden Benachrichtigungen
        channelKey:
            'mbg_all_notifications', // GEÄNDERT: Neuer gemeinsamer Kanal
        title: title,
        body: body,
        category: NotificationCategory.Progress,
        notificationLayout: NotificationLayout
            .BigText, // Verwende BigText für bessere Textdarstellung
        progress: overallPct,
        locked: false, // Nicht mehr sperren
        displayOnForeground: true,
        displayOnBackground: true,
        autoDismissible: true, // Automatisch schließen
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'OPEN_APP',
          label: 'Öffnen',
          autoDismissible: true,
        ),
      ],
    );
  } catch (e) {
    // debugPrint('Fehler beim Senden der Benachrichtigung: $e');
  }
}

/// Struktur, die wir an den Isolate übergeben (RootIsolateToken, SendPort usw.).
class _RetryFailedRequestsIsolateInput {
  final RootIsolateToken rootIsolateToken;
  final SendPort progressSender;
  final bool notificationsAllowed;

  const _RetryFailedRequestsIsolateInput({
    required this.rootIsolateToken,
    required this.progressSender,
    required this.notificationsAllowed,
  });
}

/// Diese Klasse bietet verbesserte HTTP-Verbindungen mit höheren Timeouts
class _ExtendedTimeoutHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // Konfiguriere den Client für robuste Verbindungen im Hintergrund
    client.connectionTimeout = Duration(minutes: 2);
    client.idleTimeout = Duration(minutes: 5);
    client.maxConnectionsPerHost = 8;
    client.autoUncompress = true;

    return client;
  }
}

/// Pausiert kurz und versucht dann die Operation erneut
Future<T> _retryWithBackoff<T>({
  required Future<T> Function() operation,
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  int retryCount = 0;
  Duration delay = initialDelay;

  while (true) {
    try {
      return await operation();
    } catch (e) {
      retryCount++;
      if (retryCount >= maxRetries) {
        // debugPrint('Max Retry-Versuche überschritten ($maxRetries): $e');
        rethrow;
      }

      // debugPrint('Fehler aufgetreten, versuche erneut in ${delay.inSeconds}s: $e');
      await Future.delayed(delay);

      // Verdoppele die Wartezeit für den nächsten Versuch (exponentielles Backoff)
      delay *= 2;
    }
  }
}

/// Die eigentliche Isolate-Funktion mit Sortierung, Gruppierung, Fortschrittsanzeige & Benachrichtigung.
_retryFailedRequestsIsolate(_RetryFailedRequestsIsolateInput input) async {
  if (!kIsWeb) {
    BG.initialize(input.rootIsolateToken);
  }

  // debugPrint('retry failed requests isolate started');
  final upsn = UploadProgressWriter();
  await upsn.awaitInitDone();
  // debugPrint('retry failed requests isolate init done');

  if (upsn.loading) {
    return;
  }
  upsn.setLoading(true);

  // Aktiviere Wakelock, um zu verhindern, dass das Gerät in den Schlafmodus wechselt
  if (!kIsWeb) {
    try {
      await WakelockPlus.enable();
      // debugPrint('Wakelock aktiviert - verhindere Geräteschlafmodus');
    } catch (e) {
      // debugPrint('Fehler beim Aktivieren des Wakelocks: $e');
    }
  }

  // Setze verbesserte HTTP-Einstellungen
  HttpOverrides.global = _ExtendedTimeoutHttpOverrides();
  HttpClient.enableTimelineLogging = kDebugMode;

  // debugPrint('HTTP-Verbindungseinstellungen optimiert für Hintergrundausführung');

  try {
    final failedReqs = await API().local.getAllFailedRequests() ?? [];
    final user = await API().user;
    if (user == null) {
      input.progressSender.send((1.0, false, null, 1.0, ''));
      upsn.setLoading(false);
      return;
    }

    bool success = true;
    final grouped = _groupRequestsByInspection(failedReqs);
    final totalRequests =
        grouped.values.fold<int>(0, (acc, list) => acc + list.length);

    if (totalRequests == 0) {
      input.progressSender.send((1.0, true, null, 1.0, ''));
      upsn.setLoading(false);
      return;
    }

    final progress = SyncProgress(totalRequests);

    // Erster Status
    input.progressSender.send(
        (0.0, null, '', 0.0, _formatDuration(progress.estimatedTimeRemaining)));
    upsn.setProgress(0.0);
    await _updateSyncNotification(progress: progress, successSoFar: true);

    // Start-Benachrichtigung mit Ton
    if (input.notificationsAllowed) {
      if (await _ensureNotificationsAllowed()) {
        // debugPrint('Sende START-Benachrichtigung mit Kanal: SYNC_COMPLETE');
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 900,
              channelKey: 'sync_complete', // Kanal mit Ton
              title: '🔄 Upload Sync gestartet',
              body:
                  'Die Synchronisierung von ${totalRequests} Requests beginnt...',
              category: NotificationCategory.Progress,
              notificationLayout: NotificationLayout.Default,
              progress: 0,
              locked: false,
              displayOnForeground: true,
              displayOnBackground: true,
              autoDismissible: true, // Automatisch schließen
            ),
            actionButtons: [
              NotificationActionButton(
                key: 'OPEN_APP',
                label: 'Öffnen',
                autoDismissible: true,
              ),
            ],
          );
        } catch (e) {
          // debugPrint('Fehler beim Senden der Start-Benachrichtigung: $e');
        }
      }
    }

    // Socket-Keepalive-Timer starten
    Timer? keepAliveTimer;
    if (!kIsWeb) {
      keepAliveTimer = Timer.periodic(Duration(seconds: 30), (_) async {
        try {
          // Sende ein einfaches Signal an den Server, um die Verbindung aktiv zu halten
          await API().tryNetwork(requestType: Helper.SimulatedRequestType.GET);
          // debugPrint('Keepalive-Signal gesendet, um Socket aktiv zu halten');
        } catch (e) {
          debugPrint('Keepalive-Signal fehlgeschlagen, ignoriere: $e');
        }
      });
    }

    for (final inspId in grouped.keys) {
      progress.currentInspectionId = inspId;
      final requests = grouped[inspId]!;
      progress.currentInspectionTotal = requests.length;
      progress.currentInspectionDone = 0;

      String? pjNr;
      try {
        if (inspId != 'Backup') {
          final (_, requestData) = requests.first;
          if (requestData != null) {
            final jsonData = requestData.json;
            if (jsonData != null) {
              final data = jsonData['data'];
              Map<String, dynamic> parsedData;

              if (data is String) {
                parsedData = Map<String, dynamic>.from(json.decode(data));
              } else {
                parsedData = Map<String, dynamic>.from(data);
              }

              pjNr = parsedData['PjNr']?.toString();
            }
          }
        }
      } catch (e) {
        debugPrint('Error extracting PJNr: $e');
      }

      await _updateSyncNotification(
        progress: progress,
        successSoFar: success,
        pjNr: pjNr,
      );

      for (int i = 0; i < requests.length; i++) {
        final (docID, rd) = requests[i];
        if (rd == null) {
          progress.doneRequests++;
          progress.currentInspectionDone++;
          continue;
        }

        final start = DateTime.now();

        // Verwende ein exponentielles Backoff-Verfahren für Wiederholungsversuche
        try {
          rd.logIfFailed = false;

          bool requestSuccess = false;

          // Verbesserte Wiederholungsstrategie mit exponentiellem Backoff
          await _retryWithBackoff(
            operation: () async {
              // Verwende die verbesserte Methode für Socket-Fehler
              final res = await API().remote.postJSONWithSocketRetry(
                    rd,
                    maxRetries: 3,
                    initialDelay: Duration(seconds: 2),
                    exponentialBackoff: true,
                  );

              if (res != null && res.statusCode ~/ 100 == 2) {
                API().local.failedRequestWasSuccessful(docID);
                requestSuccess = true;
                return true;
              } else {
                debugPrint(
                    'Request fehlgeschlagen mit Status: ${res?.statusCode ?? "null"}');
                return false;
              }
            },
            maxRetries:
                3, // Insgesamt bis zu 9 Versuche (3 in operation * 3 hier)
            initialDelay: Duration(seconds: 5),
          ).catchError((e) {
            debugPrint('Alle Wiederholungsversuche fehlgeschlagen: $e');
            throw e; // Fehler weitergeben
          });

          if (!requestSuccess) {
            debugPrint('Request war nach mehreren Versuchen nicht erfolgreich');
            success = false;
            break;
          }
        } catch (e) {
          debugPrint('Kritischer Fehler bei der Verarbeitung: $e');
          success = false;
          break;
        }

        final dur = DateTime.now().difference(start);
        progress.updateTiming(dur);

        progress.doneRequests++;
        progress.currentInspectionDone++;

        final overall = progress.overallProgress;
        final inspProg = progress.currentInspectionProgress;
        final etaStr = _formatDuration(progress.estimatedTimeRemaining);

        input.progressSender.send((overall, null, inspId, inspProg, etaStr));
        upsn.setProgress(overall);

        await _updateSyncNotification(
          progress: progress,
          successSoFar: success,
          pjNr: pjNr,
        );

        if (!success) break;
      }
      if (!success) break;
    }

    // Beende den Keepalive-Timer
    keepAliveTimer?.cancel();

    // Ende
    final finalOverall = progress.overallProgress;
    debugPrint('Final overall progress: $finalOverall');

    input.progressSender.send((finalOverall, success, null, 1.0, ''));
    upsn.setProgress(finalOverall);
    upsn.setSuccess(success);
    upsn.setLoading(false);

    // Abschließende Notification
    if (input.notificationsAllowed) {
      if (await _ensureNotificationsAllowed()) {
        if (success) {
          debugPrint('Sende ERFOLGS-Benachrichtigung mit gemeinsamen Kanal');
          try {
            // NUR diese Benachrichtigung erzeugt einen Ton (sync_complete Kanal)
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: 999, // Eindeutige ID für die Erfolgsbenachrichtigung
                channelKey:
                    'mbg_all_notifications', // GEÄNDERT: Neuer gemeinsamer Kanal
                title: '✅ Upload Sync Done',
                body: 'Offline Änderungen wurden erfolgreich synchronisiert.',
                category: NotificationCategory.Progress,
                notificationLayout: NotificationLayout.Default,
                progress: 100,
                locked: false,
                displayOnForeground: true,
                displayOnBackground: true,
                autoDismissible:
                    false, // Diese Benachrichtigung NICHT automatisch schließen
              ),
              actionButtons: [
                NotificationActionButton(
                  key: 'OPEN_APP',
                  label: 'Öffnen',
                  autoDismissible: true,
                ),
              ],
            );
          } catch (e) {
            debugPrint('Fehler beim Senden der Erfolgs-Benachrichtigung: $e');
          }
        } else {
          debugPrint('Sende FEHLER-Benachrichtigung mit gemeinsamen Kanal');
          try {
            // Fehlerbenachrichtigung - kein Ton
            await AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: 997, // Eindeutige ID für die Fehlerbenachrichtigung
                channelKey:
                    'mbg_all_notifications', // GEÄNDERT: Neuer gemeinsamer Kanal
                title: '❌ Upload Sync Failed',
                body: 'Einige Uploads konnten nicht verarbeitet werden.',
                category: NotificationCategory.Progress,
                notificationLayout: NotificationLayout.Default,
                progress: 100,
                locked: false,
                displayOnForeground: true,
                displayOnBackground: true,
                autoDismissible: true, // Automatisch schließen
              ),
              actionButtons: [
                NotificationActionButton(
                  key: 'OPEN_APP',
                  label: 'Öffnen',
                  autoDismissible: true,
                ),
              ],
            );
          } catch (e) {
            debugPrint('Fehler beim Senden der Fehler-Benachrichtigung: $e');
          }
        }
      }
    }
  } finally {
    // Deaktiviere Wakelock am Ende, unabhängig vom Ergebnis
    if (!kIsWeb) {
      try {
        await WakelockPlus.disable();
        debugPrint('Wakelock deaktiviert');
      } catch (e) {
        debugPrint('Fehler beim Deaktivieren des Wakelocks: $e');
      }
    }

    // Setze HTTP-Overrides zurück
    HttpOverrides.global = null;
  }
}

/// Repräsentiert eine gruppierte Inspektion mit allen relevanten Informationen
class GroupedInspection {
  final String pjNr;
  final List<String> requests;
  final int total;
  final int completed;
  final double progress;
  final Map<String, int>
      requestTypes; // Neue Map für die verschiedenen Request-Typen
  final int totalSize; // Gesamtgröße aller Requests in Bytes
  final DateTime lastModified; // Zeitstempel der letzten Änderung

  GroupedInspection({
    required this.pjNr,
    required this.requests,
    required this.total,
    required this.completed,
    required this.progress,
    required this.requestTypes,
    required this.totalSize,
    required this.lastModified,
  });

  // Hilfsmethode zum Formatieren der Größe
  String get formattedSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024)
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Hilfsmethode zum Formatieren des Zeitstempels
  String get formattedLastModified {
    final now = DateTime.now();
    final difference = now.difference(lastModified);

    if (difference.inDays > 0) return '${difference.inDays} Tage';
    if (difference.inHours > 0) return '${difference.inHours} Stunden';
    if (difference.inMinutes > 0) return '${difference.inMinutes} Minuten';
    return '${difference.inSeconds} Sekunden';
  }
}

/// Fordert die Benachrichtigungsberechtigung an
Future<bool> _requestNotificationPermission() async {
  debugPrint('Fordere Benachrichtigungsberechtigung an...');

  // Initialisiere die Benachrichtigungen mit nur einem Kanal
  await AwesomeNotifications().initialize(
    'resource://drawable/ic_icon',
    [
      NotificationChannel(
        channelKey:
            'mbg_all_notifications', // GEÄNDERT: Neuer gemeinsamer Kanal
        channelName: 'MBG App Benachrichtigungen',
        channelDescription: 'Alle Benachrichtigungen der MBG App',
        defaultColor: Colors.blue,
        importance:
            NotificationImportance.Max, // Maximale Priorität für Sichtbarkeit
        playSound: true, // Sound einschalten für bessere Erkennung
        enableVibration: true, // Vibration für bessere Erkennung
        ledColor: Colors.blue,
      ),
    ],
  );

  // Keine Test-Benachrichtigung mehr senden
  debugPrint('Benachrichtigungskanal erfolgreich initialisiert');
  return true;
}

/// Öffnet die Speichereinstellungen direkt
Future<void> _openStorageSettings() async {
  try {
    // Für alle Plattformen - öffnet die App-Einstellungen, meist direkt zur Speicherseite
    await openAppSettings();
    debugPrint('Speichereinstellungen geöffnet');
  } catch (e) {
    debugPrint('Fehler beim Öffnen der Speichereinstellungen: $e');
  }
}

/// Prüft alle notwendigen Berechtigungen für die Synchronisierung
Future<bool> _checkPermissions(BuildContext context) async {
  debugPrint('Prüfe Berechtigungen...');

  // Prüfe und fordere Benachrichtigungsberechtigung an
  final notificationStatus =
      await AwesomeNotifications().isNotificationAllowed();
  if (!notificationStatus) {
    debugPrint(
        'Benachrichtigungen sind nicht erlaubt, fordere Berechtigung an...');

    // Versuche die Berechtigung anzufordern
    final permissionGranted = await _requestNotificationPermission();
    if (!permissionGranted) {
      // Zeige Dialog zum Aktivieren der Benachrichtigungen
      final bool? shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Benachrichtigungen aktivieren'),
            content: Text(
                'Um den Fortschritt der Synchronisierung zu sehen, müssen Benachrichtigungen aktiviert werden. Möchten Sie die Einstellungen öffnen?'),
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
        debugPrint('Öffne App-Einstellungen...');
        // Öffne die App-Einstellungen
        await openAppSettings();

        // Warte kurz und prüfe dann erneut
        await Future.delayed(Duration(seconds: 1));
        final newStatus = await AwesomeNotifications().isNotificationAllowed();
        if (!newStatus) {
          debugPrint('Benachrichtigungen immer noch nicht erlaubt');
          showToast(
              'Bitte erlauben Sie Benachrichtigungen in den Einstellungen');
          return false;
        }
        debugPrint('Benachrichtigungen wurden aktiviert');
      } else {
        debugPrint('Benutzer hat abgebrochen');
        showToast('Bitte erlauben Sie Benachrichtigungen in den Einstellungen');
        return false;
      }
    }
  }

  debugPrint('Alle Berechtigungen sind vorhanden');
  return true;
}

/// Haupt-Klasse, die den Upload orchestriert und im UI aufgerufen wird.
class FailedRequestmanager {
  /// Gruppiert die fehlgeschlagenen Requests nach PJNr
  Future<List<GroupedInspection>> getGroupedFailedRequests() async {
    debugPrint('getGroupedFailedRequests: Starte...');
    final failedReqs = await API().local.getAllFailedRequests() ?? [];
    debugPrint('getGroupedFailedRequests: ${failedReqs.length} fehlgeschlagene Requests gefunden');

    Map<String, Map<String, dynamic>> groupedRequests = {};

    for (var (id, requestData) in failedReqs) {
      try {
        if (requestData != null) {
          final jsonData = requestData.json;
          if (jsonData != null) {
            final data = jsonData['data'];
            Map<String, dynamic> parsedData;

            if (data is String) {
              parsedData = Map<String, dynamic>.from(json.decode(data));
            } else {
              parsedData = Map<String, dynamic>.from(data);
            }

            final pjNr = parsedData['PjNr']?.toString() ?? 'Unbekannt';
            final route = requestData.route;
            final timestamp = DateTime.fromMillisecondsSinceEpoch(int.parse(id, radix: 36));

            if (!groupedRequests.containsKey(pjNr)) {
              groupedRequests[pjNr] = {
                'requests': <String>[],
                'total': 0,
                'completed': 0,
                'progress': 0.0,
                'requestTypes': <String, int>{},
                'totalSize': 0, // Set to 0 or skip for large batches
                'lastModified': timestamp,
              };
            }

            // Aktualisiere die Map mit den Request-Informationen
            final group = groupedRequests[pjNr]!;
            (group['requests'] as List<String>).add(route);
            group['total'] = (group['total'] as int) + 1;

            // Zähle die Request-Typen
            final requestType = route.split('/').first;
            group['requestTypes'][requestType] =
                (group['requestTypes'][requestType] ?? 0) + 1;

            // Do NOT serialize the full request, just estimate or skip size
            // group['totalSize'] = (group['totalSize'] as int) + 0;

            // Aktualisiere den Zeitstempel der letzten Änderung
            if (timestamp.isAfter(group['lastModified'] as DateTime)) {
              group['lastModified'] = timestamp;
            }

            if (parsedData['offline'] == false) {
              group['completed'] = (group['completed'] as int) + 1;
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing request: $e');
      }
    }

    debugPrint('getGroupedFailedRequests: ${groupedRequests.length} verschiedene Inspektionen gefunden');

    // Berechne den Fortschritt für jede Inspektion
    for (var pjNr in groupedRequests.keys) {
      final total = groupedRequests[pjNr]!['total'] as int;
      final completed = groupedRequests[pjNr]!['completed'] as int;
      groupedRequests[pjNr]!['progress'] = total > 0 ? completed / total : 0.0;
    }

    // Konvertiere die Map in eine Liste von GroupedInspection Objekten
    final result = groupedRequests.entries
        .map((entry) => GroupedInspection(
              pjNr: entry.key,
              requests: List<String>.from(entry.value['requests'] as List),
              total: entry.value['total'] as int,
              completed: entry.value['completed'] as int,
              progress: entry.value['progress'] as double,
              requestTypes:
                  Map<String, int>.from(entry.value['requestTypes'] as Map),
              totalSize: entry.value['totalSize'] as int,
              lastModified: entry.value['lastModified'] as DateTime,
            ))
        .toList();

    debugPrint('getGroupedFailedRequests: Fertig. ${result.length} Inspektionen zurückgegeben');
    return result;
  }

  /// Startet den Upload, ggf. mit fortlaufender Progress-Callback.
  Future<bool> retryFailedrequests({
    required BuildContext context,
    void Function(double overallProgress, bool? success, String? currentInspId,
            double currentInspProgress, String etaString)?
        onProgress,
  }) async {
    debugPrint('retry failed requests started');

    // Prüfe zuerst alle Berechtigungen
    if (!await _checkPermissions(context)) {
      return false;
    }

    try {
      // Check Internet
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.PUT);
    } catch (e) {
      showToast('Keine funktionierende Internetverbindung');
      return false;
    }

    // Notifications erlauben?
    bool notificationsAllowed = await allowNotificationGuard(
      context,
      'Wir können dir eine Benachrichtigung über den Sync-Fortschritt senden.',
    );

    bool finalSuccess = false;
    final progressReceiver = ReceivePort();

    final isolateInputData = _RetryFailedRequestsIsolateInput(
      rootIsolateToken: RootIsolateToken.instance!,
      progressSender: progressReceiver.sendPort,
      notificationsAllowed: notificationsAllowed,
    );

    final subscription = progressReceiver.listen((msg) {
      // msg: (double overall, bool? succ, String? inspId, double inspProg, String eta)
      final (overall, maybeSuccess, inspId, inspProg, etaStr) =
          msg as (double, bool?, String?, double, String);

      if (maybeSuccess != null) {
        // => Upload beendet
        finalSuccess = maybeSuccess;
        progressReceiver.close();
      } else {
        // => Zwischenschritt
        onProgress?.call(overall, null, inspId, inspProg, etaStr);
      }
    });

    // Statt über ein echtes Isolate (spawn) auszulagern,
    // rufen wir hier direkt die Upload-Logik asynchron auf:
    await _retryFailedRequestsIsolate(isolateInputData);

    // Warten, bis sämtliche Nachrichten gelesen wurden:
    await subscription.asFuture();

    // Letztes "onProgress", um finalen Erfolg zu signalisieren:
    onProgress?.call(1.0, finalSuccess, null, 1.0, '');

    return finalSuccess;
  }

  /// Andere Methoden wie loadAndCacheAll, setOnlineAll etc. können hier bleiben ...
  Future<bool> loadAndCacheAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // base-case: CheckPointDefects have no children
    if (depth == 0) return true;
    depth--;
    try {
      //fail early if no connection
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.GET);
      //get all children, this will also cache them internally
      var children = await caller
          .all(preloadFullImages: Options().preloadFullImagesOnManualDownload)
          .last;
      if (caller.currentData is InspectionLocation) {
        final location = caller.currentData as InspectionLocation;
        if (location.dokuspaths != null && location.dokuspaths!.isNotEmpty) {
          var docus = location.dokuspaths;
          if (docus != null) {
            assert((await API().user) != null,
                'Niemand eingeloggt'); // Using string directly instead of S.current
            for (var doc in docus) {
              await API().getDocument(doc.docupath);
            }
          }
        }
      }

      var didSucceed = await Future.wait(children.map(
        (child) async {
          if (depth == 0)
            return true; //base-case as to not call generateNextModel
          bool childSucceeded = await loadAndCacheAll(
              caller.generateNextModel(child), depth,
              name: name, parentID: caller.currentData.id);
          return childSucceeded;
        },
      ));

      //if all children succeeded recursive calling succeeded
      bool success = didSucceed.every((el) => el);
      if (success) {
        caller.currentData.forceOffline = true;
        if (parentID == null) return false;

        try {
          await API().local.storeData(caller.currentData, forId: parentID);
        } catch (e) {
          return false;
        }
      }

      return success;
    } catch (error) {
      debugPrint('failed! ${depth + 1}');
      showToast(error.toString() +
          "\n" +
          'Probiere es später nochmal'); // Using string directly instead of S.current
      return false; //failed
    }
  }

  Future<void> setOnlineAll<ChildData, ParentData, DDModel>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // ...
  }
}
