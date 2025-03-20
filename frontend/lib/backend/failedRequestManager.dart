import 'dart:async';
import 'dart:isolate';
import 'dart:convert'; // für jsonDecode

import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:MBG_Inspektionen/notifications/controller.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../classes/dropdownClasses.dart';
import '../classes/user.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import '../helpers/background.dart' as BG;
import '../helpers/toast.dart';
import '../pages/checkcategories.dart';
import '../pages/location.dart';
import 'api.dart';
import 'helpers.dart' as Helper;

import 'package:awesome_notifications/awesome_notifications.dart';

final sync_progress_str = 'sync progress';
final sync_in_progress_str = 'sync in progress';
final sync_success_str = 'sync success';

/// Beispiel: Wir bauen eine kleine Klasse, um
/// den Fortschritt (global + pro Inspektion) verwalten zu können.
class SyncProgress {
  final int totalRequests; // alle Requests über alle Inspektionen
  int doneRequests = 0; // bisherige erfolgreich bearbeitete Requests

  String currentInspectionId = '';
  int currentInspectionTotal = 0;
  int currentInspectionDone = 0;

  DateTime startTime = DateTime.now();

  // Für ETA
  double averageTimePerRequest = 0;
  int _accumulatedDurationMs = 0;
  int _requestCount = 0;

  SyncProgress(this.totalRequests);

  double get overallProgress =>
      (totalRequests == 0) ? 1.0 : (doneRequests / totalRequests);

  double get currentInspectionProgress => (currentInspectionTotal == 0)
      ? 1.0
      : (currentInspectionDone / currentInspectionTotal);

  Duration get estimatedTimeRemaining {
    final remaining = totalRequests - doneRequests;
    if (remaining <= 0 || averageTimePerRequest <= 0) {
      return Duration.zero;
    }
    return Duration(milliseconds: (averageTimePerRequest * remaining).round());
  }

  /// Aufrufen nach jedem erfolgreichen Upload, um die durchschnittliche
  /// Zeit pro Request (-> ETA) zu aktualisieren.
  void updateTiming(Duration requestTime) {
    _accumulatedDurationMs += requestTime.inMilliseconds;
    _requestCount++;
    averageTimePerRequest = _accumulatedDurationMs / _requestCount;
  }
}

/// Struktur, die unsere Isolate-Funktion benötigt
/// (mit dem RootIsolateToken, dem SendPort usw.).
class _RetryFailedRequestsIsolateInput {
  final RootIsolateToken rootIsolateToken;
  final SendPort progressSender;
  final bool notificationsAllowed;
  const _RetryFailedRequestsIsolateInput({
    required this.rootIsolateToken,
    required this.progressSender,
    this.notificationsAllowed = false,
  });
}

/// Diese Funktion parst das "raw JSON" in rd.json['data']
/// und holt daraus z.B. local_id oder PjNr, um zu gruppieren.
///
/// Pseudocode, passt du ggf. an, falls du lieber PjNr als ID nutzt.
String _extractInspectionIdFromRequest(RequestData rd) {
  try {
    // rd.json sollte z.B. so aussehen: {
    //   "type": "location",
    //   "data": "{\"local_id\":\"6006358-undefined-undefined-undefined\",\"PjNr\":6006358,...}",
    //   "user": {...}
    // }
    final dataField = rd.json?['data'];
    if (dataField is String) {
      // parse
      final parsed = jsonDecode(dataField) as Map<String, dynamic>;
      // z.B. local_id oder PjNr
      final localId = parsed['local_id'] as String?;
      if (localId != null && localId.isNotEmpty) {
        return localId;
      }
      // fallback: PjNr als String
      final pjNr = parsed['PjNr']?.toString() ?? 'unknown';
      return pjNr;
    }
  } catch (e) {
    debugPrint('Fehler beim Lesen der inspectionId: $e');
  }
  return 'unknown';
}

/// Gruppiert die Requests nach local_id (o.ä.) und sortiert sie.
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

  // Keys sortieren (z.B. lexikographisch)
  final sortedKeys = grouped.keys.toList()..sort();
  final sortedMap = <String, List<(String, RequestData?)>>{};
  for (final k in sortedKeys) {
    sortedMap[k] = grouped[k]!;
  }
  return sortedMap;
}

/// Updated während der Synchronisation eine "laufende" Notification
/// (immer dieselbe ID => fortlaufende Aktualisierung).
void _updateSyncNotification({
  required SyncProgress progress,
  required bool successSoFar,
}) {
  final overallPct = (progress.overallProgress * 100).round().toDouble();
  final inspPct = (progress.currentInspectionProgress * 100).round().toDouble();

  final eta = progress.estimatedTimeRemaining;
  final etaStr =
      eta.inMinutes > 0 ? '${eta.inMinutes} min' : '${eta.inSeconds} s';

  final title =
      successSoFar ? 'Upload Sync läuft ...' : 'Upload Sync (mit Fehlern)';

  AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: 999, // gleiche ID => aktualisiert sich
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

/// Das Herzstück: Hier führen wir das "Retry-Failed-Request" durch,
/// gruppiert nach Inspektions-ID, sortiert, mit UI-/Notification-Fortschritt.
_retryFailedRequestsIsolate(
  _RetryFailedRequestsIsolateInput input,
) async {
  if (!kIsWeb) {
    BG.initialize(input.rootIsolateToken);
  }

  debugPrint('retry failed requests isolate started');

  final upsn = UploadProgressWriter();
  await upsn.awaitInitDone();
  debugPrint('retry failed requests isolate init done');

  final is_already_running = upsn.loading;
  if (is_already_running) {
    // Läuft bereits
    return;
  } else {
    upsn.setLoading(true);
  }

  final failedReqs = await API().local.getAllFailedRequests() ?? [];
  DisplayUser? user = await API().user;
  if (user == null) {
    input.progressSender.send((1.0, false));
    upsn.setLoading(false);
    return;
  }

  bool success = true;
  final grouped = _groupRequestsByInspection(failedReqs);

  // Gesamtanzahl
  final totalRequests =
      grouped.values.fold<int>(0, (acc, list) => acc + list.length);
  if (totalRequests == 0) {
    // Nichts zu tun
    input.progressSender.send((1.0, true));
    upsn.setLoading(false);
    return;
  }

  // Fortschrittsdaten
  final progress = SyncProgress(totalRequests);
  progress.startTime = DateTime.now();

  // Anfang: UI und Notification auf 0%
  input.progressSender.send((0.0, null));
  upsn.setProgress(0.0);
  _updateSyncNotification(progress: progress, successSoFar: success);

  // Über alle Inspektionen (sortiert)
  for (final inspectionId in grouped.keys) {
    progress.currentInspectionId = inspectionId;
    final requestsInInsp = grouped[inspectionId]!;
    progress.currentInspectionTotal = requestsInInsp.length;
    progress.currentInspectionDone = 0;

    // Innerer Loop: alle Requests dieser Inspektion
    for (int i = 0; i < requestsInInsp.length; i++) {
      final (docID, rd) = requestsInInsp[i];
      // Falls rd == null => überspringen
      if (rd == null) {
        progress.doneRequests++;
        progress.currentInspectionDone++;
        continue;
      }

      // Timer pro Request
      final requestStart = DateTime.now();
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

      // Zeitmessung + ETA-Update
      final singleDur = DateTime.now().difference(requestStart);
      progress.updateTiming(singleDur);

      // Fortschrittszähler
      progress.doneRequests++;
      progress.currentInspectionDone++;

      // UI-Update => Sende (Fortschritt, null)
      final overall = progress.overallProgress;
      input.progressSender.send((overall, null));
      upsn.setProgress(overall);

      // Notification aktualisieren
      _updateSyncNotification(progress: progress, successSoFar: success);

      if (!success) break;
    }
    if (!success) break; // Abbruch auch aus äußerer Schleife
  }

  // Ende: Sende (1.0, success)
  input.progressSender.send((1.0, success));
  upsn.setProgress(1.0);
  upsn.setSuccess(success);
  upsn.setLoading(false);

  // Finale Notification (z.B. mit Ton)
  if (input.notificationsAllowed) {
    if (success) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999,
          channelKey: 'progress',
          title: Emojis.symbols_check_mark_button + ' Upload Sync Done',
          body: 'Offline Änderungen wurden erfolgreich synchronisiert.',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.Default,
          progress: 100,
          // soundSource: 'resource://raw/res_custom_success_tone', // optional
        ),
      );
    } else {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 999,
          channelKey: 'progress',
          title: Emojis.symbols_cross_mark + ' Upload Sync Failed',
          body:
              'Einige Uploads konnten nicht verarbeitet werden. Bitte erneut versuchen.',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.Default,
          progress: 100,
          // soundSource: 'resource://raw/res_custom_failure_tone', // optional
        ),
      );
    }
  }
}

/// Deine Manager-Klasse (unverändert), aber an ein-zwei Stellen
/// minimal angepasst, damit wir den Isolate-Code triggern.
class FailedRequestmanager {
  Future<bool> retryFailedrequests({
    required BuildContext context,
    void Function(double)? onProgress,
  }) async {
    debugPrint('retry failed requests started');
    try {
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.PUT);
    } catch (e) {
      showToast(S.current!.noViableInternetConnection);
      return false;
    }

    bool notificationsAllowed = await allowNotificationGuard(
      context,
      S.of(context).weCanSendYouANotificationAboutTheSyncProgress,
    );

    bool success = false;
    // Empfänger für Fortschritt
    ReceivePort progressReceiver = ReceivePort();

    var isolateInputData = _RetryFailedRequestsIsolateInput(
      rootIsolateToken: RootIsolateToken.instance!,
      progressSender: progressReceiver.sendPort,
      notificationsAllowed: notificationsAllowed,
    );

    // Den Stream abonnieren
    final subscription = progressReceiver.listen((msg) {
      final (progressValue, maybeSuccess) = msg as (double, bool?);
      if (maybeSuccess != null) {
        // Upload abgeschlossen => Erfolg/Fehlschlag
        success = maybeSuccess;
        progressReceiver.close();
      } else {
        // Laufendes Progress-Update
        onProgress?.call(progressValue);
      }
    });

    // Falls du es wirklich in einem Isolate laufen lassen willst:
    // await Isolate.spawn(_retryFailedRequestsIsolate, isolateInputData);
    // Hier: direkter Aufruf
    await _retryFailedRequestsIsolate(isolateInputData);

    // Warte auf das Ende
    await subscription.asFuture();

    return success;
  }

  /// Deine übrigen Methoden z.B. loadAndCacheAll, setOnlineTotal usw.:
  /// ...
  /// Hier unverändert.
  Future<bool> loadAndCacheAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // ...
    return false;
  }

  Future setOnlineAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // ...
    return;
  }
}
