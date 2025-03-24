import 'dart:async';
import 'dart:isolate';
import 'dart:convert';

import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/helpers/background.dart' as BG;
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/backend/helpers.dart' as Helper;
import 'package:flutter/services.dart';

import '../notifications/controller.dart';

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

  SyncProgress(this.totalRequests);

  double get overallProgress =>
      (totalRequests == 0) ? 1.0 : doneRequests / totalRequests;

  double get currentInspectionProgress => (currentInspectionTotal == 0)
      ? 1.0
      : currentInspectionDone / currentInspectionTotal;

  Duration get estimatedTimeRemaining {
    final remaining = totalRequests - doneRequests;
    if (remaining <= 0 || averageTimePerRequest <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (averageTimePerRequest * remaining).round());
  }

  /// Nach jedem Request aufrufen, um die Durchschnittszeit pro Request zu aktualisieren.
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
    Map<String, dynamic> parsedData;

    if (dataField is String) {
      // Wenn data ein JSON-String ist, parsen wir ihn
      parsedData = Map<String, dynamic>.from(json.decode(dataField));
    } else {
      // Wenn data bereits ein Objekt ist, verwenden wir es direkt
      parsedData = Map<String, dynamic>.from(dataField);
    }

    // Versuche zuerst die PjNr zu extrahieren
    final pjNr = parsedData['PjNr']?.toString();
    if (pjNr != null && pjNr.isNotEmpty) {
      return pjNr;
    }

    // Fallback: local_id
    final localId = parsedData['local_id'] as String?;
    if (localId != null && localId.isNotEmpty) {
      return localId;
    }
  } catch (e) {
    debugPrint('Could not parse inspectionId: $e');
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

/// Aktualisiert die laufende Sync-Notification (immer selbe ID => fortlaufendes Update).
void _updateSyncNotification({
  required SyncProgress progress,
  required bool successSoFar,
}) {
  final overallPct = (progress.overallProgress * 100).round().toDouble();
  final inspPct = (progress.currentInspectionProgress * 100).round();
  final etaStr = _formatDuration(progress.estimatedTimeRemaining);

  final title = successSoFar ? 'Upload Sync läuft ...' : 'Upload Sync (Fehler)';

  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 999,
      channelKey: 'progress',
      title: title,
      body: 'Inspektion: ${progress.currentInspectionId}\n'
          'Inspektions-Fortschritt: $inspPct%\n'
          'Gesamt-Fortschritt: $overallPct%\n'
          'Verbleibende Zeit: ~ $etaStr',
      category: NotificationCategory.Progress,
      notificationLayout: NotificationLayout.Default,
      progress: overallPct,
      locked: true,
    ),
  );
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

/// Die eigentliche Isolate-Funktion mit Sortierung, Gruppierung, Fortschrittsanzeige & Benachrichtigung.
_retryFailedRequestsIsolate(_RetryFailedRequestsIsolateInput input) async {
  if (!kIsWeb) {
    BG.initialize(input.rootIsolateToken);
  }

  debugPrint('retry failed requests isolate started');
  final upsn = UploadProgressWriter();
  await upsn.awaitInitDone();
  debugPrint('retry failed requests isolate init done');

  if (upsn.loading) {
    // Läuft bereits
    return;
  }
  upsn.setLoading(true);

  final failedReqs = await API().local.getAllFailedRequests() ?? [];
  final user = await API().user;
  if (user == null) {
    // Sende finalen Stand
    input.progressSender.send((1.0, false, null, 1.0, ''));
    upsn.setLoading(false);
    return;
  }

  bool success = true;
  final grouped = _groupRequestsByInspection(failedReqs);
  final totalRequests =
      grouped.values.fold<int>(0, (acc, list) => acc + list.length);

  if (totalRequests == 0) {
    // nix zu tun
    input.progressSender.send((1.0, true, null, 1.0, ''));
    upsn.setLoading(false);
    return;
  }

  // Fortschritts-Daten
  final progress = SyncProgress(totalRequests);

  // Erster Status
  input.progressSender.send(
      (0.0, null, '', 0.0, _formatDuration(progress.estimatedTimeRemaining)));
  upsn.setProgress(0.0);
  _updateSyncNotification(progress: progress, successSoFar: true);

  // Loop über alle Inspektionen
  for (final inspId in grouped.keys) {
    progress.currentInspectionId = inspId;
    final requests = grouped[inspId]!;
    progress.currentInspectionTotal = requests.length;
    progress.currentInspectionDone = 0;

    // Extrahiere PJNr aus dem Request
    String? pjNr;
    try {
      if (inspId != 'Backup') {
        final failedReqs = await API().local.getAllFailedRequests();
        if (failedReqs != null) {
          for (var req in failedReqs) {
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

            final localId = parsedData['local_id'] as String?;
            if (localId == inspId) {
              pjNr = parsedData['PjNr']?.toString();
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting PJNr: $e');
    }

    for (int i = 0; i < requests.length; i++) {
      final (docID, rd) = requests[i];
      if (rd == null) {
        progress.doneRequests++;
        progress.currentInspectionDone++;
        continue;
      }

      // Request senden
      final start = DateTime.now();
      try {
        rd.logIfFailed = false;
        final res = await API().remote.postJSON(rd);
        if (res!.statusCode ~/ 100 == 2) {
          API().local.failedRequestWasSuccessful(docID);
        } else {
          success = false;
          break;
        }
      } catch (e) {
        success = false;
        break;
      }

      // Zeitmessung & Counter
      final dur = DateTime.now().difference(start);
      progress.updateTiming(dur);

      progress.doneRequests++;
      progress.currentInspectionDone++;

      final overall = progress.overallProgress;
      final inspProg = progress.currentInspectionProgress;
      final etaStr = _formatDuration(progress.estimatedTimeRemaining);

      // Sende an Main: (gesamtFortschritt, success?, inspId, inspProgress, eta)
      input.progressSender.send((overall, null, inspId, inspProg, etaStr));
      upsn.setProgress(overall);

      _updateSyncNotification(progress: progress, successSoFar: success);
      if (!success) break;
    }
    if (!success) break;
  }

  // Ende
  input.progressSender.send((1.0, success, null, 1.0, ''));
  upsn.setProgress(1.0);
  upsn.setSuccess(success);
  upsn.setLoading(false);

  // Abschließende Notification
  if (input.notificationsAllowed) {
    if (success) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999,
          channelKey: 'progress',
          title: '✅ Upload Sync Done',
          body: 'Offline Änderungen wurden erfolgreich synchronisiert.',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.Default,
          progress: 100,
          locked: false,
        ),
      );
    } else {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999,
          channelKey: 'progress',
          title: '❌ Upload Sync Failed',
          body: 'Einige Uploads konnten nicht verarbeitet werden.',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.Default,
          progress: 100,
          locked: false,
        ),
      );
    }
  }
}

/// Repräsentiert eine gruppierte Inspektion mit allen relevanten Informationen
class GroupedInspection {
  final String pjNr;
  final List<String> requests;
  final int total;
  final int completed;
  final double progress;

  GroupedInspection({
    required this.pjNr,
    required this.requests,
    required this.total,
    required this.completed,
    required this.progress,
  });
}

/// Haupt-Klasse, die den Upload orchestriert und im UI aufgerufen wird.
class FailedRequestmanager {
  /// Gruppiert die fehlgeschlagenen Requests nach PJNr
  Future<List<GroupedInspection>> getGroupedFailedRequests() async {
    final failedReqs = await API().local.getAllFailedRequests() ?? [];
    Map<String, Map<String, dynamic>> groupedRequests = {};

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
          groupedRequests[pjNr] = {
            'requests': [],
            'total': 0,
            'completed': 0,
            'progress': 0.0
          };
        }

        groupedRequests[pjNr]!['requests']!
            .add(requestData['route'] ?? 'Unbekannte Route');
        groupedRequests[pjNr]!['total'] =
            (groupedRequests[pjNr]!['total'] as int) + 1;

        if (parsedData['offline'] == false) {
          groupedRequests[pjNr]!['completed'] =
              (groupedRequests[pjNr]!['completed'] as int) + 1;
        }
      } catch (e) {
        debugPrint('Error parsing request: $e');
      }
    }

    // Berechne den Fortschritt für jede Inspektion
    for (var pjNr in groupedRequests.keys) {
      final total = groupedRequests[pjNr]!['total'] as int;
      final completed = groupedRequests[pjNr]!['completed'] as int;
      groupedRequests[pjNr]!['progress'] = total > 0 ? completed / total : 0.0;
    }

    // Konvertiere die Map in eine Liste von GroupedInspection Objekten
    return groupedRequests.entries
        .map((entry) => GroupedInspection(
              pjNr: entry.key,
              requests: List<String>.from(entry.value['requests'] as List),
              total: entry.value['total'] as int,
              completed: entry.value['completed'] as int,
              progress: entry.value['progress'] as double,
            ))
        .toList();
  }

  /// Startet den Upload, ggf. mit fortlaufender Progress-Callback.
  Future<bool> retryFailedrequests({
    required BuildContext context,
    void Function(double overallProgress, bool? success, String? currentInspId,
            double currentInspProgress, String etaString)?
        onProgress,
  }) async {
    debugPrint('retry failed requests started');
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
  Future<bool> loadAndCacheAll<ChildData, ParentData, DDModel>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // ...
    return false;
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
