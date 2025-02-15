import 'dart:async';
import 'dart:isolate';
import 'dart:convert'; // für json.decode

import 'package:MBG_Inspektionen/backend/progressManagerStateNotifier.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/notifications/controller.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../classes/dropdownClasses.dart';
import '../classes/requestData.dart';
import '../classes/user.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import '../helpers/background.dart' as BG;
import '../helpers/toast.dart';
import '../pages/checkcategories.dart';
import '../pages/location.dart';
import 'api.dart';
import 'helpers.dart' as Helper;

import 'package:awesome_notifications/awesome_notifications.dart';

// Diese drei Strings scheinen in deinem Projekt benutzt zu werden.
// Wenn sie nicht gebraucht werden, kannst du sie entfernen.
final sync_progress_str = 'sync progress';
final sync_in_progress_str = 'sync in progress';
final sync_success_str = 'sync success';

/// Kleine Hilfsklasse, um aus dem Tupel (docID, RequestData) zusätzlich die pjNr zu extrahieren.
class _FailedRequestWithPjNr {
  final String docID;
  final RequestData requestData;
  final int pjNr;

  _FailedRequestWithPjNr({
    required this.docID,
    required this.requestData,
    required this.pjNr,
  });
}

/// Input-Datenklasse für den Isolate, damit wir
/// - den RootIsolateToken (für BG-Init)
/// - den SendPort (Fortschritts-Updates)
/// - die Info, ob Notifications erlaubt sind
/// mitgeben können.
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

/// Die eigentliche Funktion, die im Isolate läuft:
/// - Lädt alle fehlgeschlagenen Requests
/// - Sortiert sie nach PjNr
/// - Versucht sie erneut hochzuladen
/// - Schickt Fortschrittsdaten zurück (per SendPort)
/// - Erstellt/aktualisiert Notifications mit Awesome Notifications
_retryFailedRequestsIsolate(_RetryFailedRequestsIsolateInput input) async {
  // Initialisierung für Hintergrund (falls nicht im Web)
  if (!kIsWeb) {
    BG.initialize(input.rootIsolateToken);
  }
  debugPrint('Isolate: retryFailedRequests gestartet.');

  // Fortschritts-Manager (verhindert Parallel-Uploads)
  final uploadState = UploadProgressWriter();
  await uploadState.awaitInitDone();

  // Falls bereits ein Upload läuft -> Abbruch
  if (uploadState.loading) {
    return;
  } else {
    uploadState.setLoading(true);
  }

  // 1) Fehlgeschlagene Requests laden
  final rawFailedRequests = await API().local.getAllFailedRequests() ?? [];

  // 2) User checken (z. B. Auth)
  DisplayUser? user = await API().user;
  if (user == null) {
    input.progressSender.send((1.0, false));
    uploadState.setLoading(false);
    return;
  }

  // 3) In neue Liste parsen, um PjNr zu extrahieren
  final List<_FailedRequestWithPjNr> failedRequests = [];
  for (final (docID, requestData) in rawFailedRequests) {
    if (requestData == null) continue;

    // Hier extrahieren wir die PjNr aus requestData.json['data'] (String)
    final dataAsString = requestData.json!['data'] as String?;
    int pjNr = 0;
    if (dataAsString != null) {
      try {
        final decoded = json.decode(dataAsString);
        // PjNr aus "decoded"
        if (decoded is Map<String, dynamic> && decoded['PjNr'] is int) {
          pjNr = decoded['PjNr'];
        }
      } catch (e) {
        debugPrint('Fehler beim JSON-Decode: $e');
      }
    }

    failedRequests.add(
      _FailedRequestWithPjNr(
        docID: docID,
        requestData: requestData,
        pjNr: pjNr,
      ),
    );
  }

  // 4) Sortieren nach PjNr aufsteigend
  failedRequests.sort((a, b) => a.pjNr.compareTo(b.pjNr));
  final totalRequests = failedRequests.length;

  debugPrint('Isolate: Gefundene fehlgeschlagene Requests: $totalRequests');

  // 5) UploadProgressWriter initialisieren
  uploadState.setProgress(0.0);

  // 6) Fortschritts-Update an Haupt-Isolate: 0%
  input.progressSender.send((0.0, null));

  // 7) Wenn Notifications erlaubt & es gibt etwas zu tun -> Anfangs-Notification
  if (input.notificationsAllowed && totalRequests > 0) {
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1, // BLEIBT 1 -> Wir überschreiben diese Notification
        channelKey: 'progress',
        title: 'Upload Sync',
        body: 'Starte Uploads ...',
        category: NotificationCategory.Progress,
        notificationLayout: NotificationLayout.ProgressBar,
        progress: 0,
        payload: NotificationPayload.progress(0, totalRequests),
      ),
    );
  }

  bool overallSuccess = true;

  // 8) Optional: Zählen, wie viele Requests pro PjNr anstehen.
  final Map<int, int> requestsPerPjNr = {};
  for (var item in failedRequests) {
    requestsPerPjNr[item.pjNr] = (requestsPerPjNr[item.pjNr] ?? 0) + 1;
  }

  // Liste aller PjNrs in aufsteigender Reihenfolge
  final pjNrsInOrder = requestsPerPjNr.keys.toList()..sort();
  final totalPjNrs = pjNrsInOrder.length;
  int currentPjNrIndex =
      0; // Damit wir tracken können, die wievielte PjNr wir gerade machen
  int lastPjNr = -1; // Zu Beginn: keine PjNr aktiv

  // 9) Hauptschleife: Retry pro Request
  for (int i = 0; i < totalRequests; i++) {
    final item = failedRequests[i];
    final docID = item.docID;
    final requestData = item.requestData;
    final pjNr = item.pjNr;

    // Fortschritt (0..1)
    final currentProgress = i / totalRequests;
    uploadState.setProgress(currentProgress);
    input.progressSender.send((currentProgress, null));

    // Wenn wir jetzt zu einer neuen PjNr wechseln, Index erhöhen
    if (pjNr != lastPjNr) {
      currentPjNrIndex++;
      lastPjNr = pjNr;
    }

    // Wieviele Requests hatte diese pjNr?
    final totalForThisPjNr = requestsPerPjNr[pjNr] ?? 1;
    // Davon ziehen wir jetzt 1 ab, weil wir *diesen* Request bearbeiten
    requestsPerPjNr[pjNr] = totalForThisPjNr - 1;
    final remainingForThisPjNr = requestsPerPjNr[pjNr]!;

    // Notification nach jedem Schritt aktualisieren (falls erlaubt)
    if (input.notificationsAllowed) {
      final textPjNr = (pjNr > 0) ? pjNr.toString() : '?';
      // "PJ x / n" = welche PjNr wir gerade haben
      final bodyText = 'Aktuelle PjNr: $textPjNr '
          '(${remainingForThisPjNr} von $totalForThisPjNr übrig) | '
          'PJ $currentPjNrIndex / $totalPjNrs';

      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1, // gleiche ID -> fortlaufendes Update
          channelKey: 'progress',
          title: 'Upload Sync',
          body: bodyText,
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.ProgressBar,
          progress: (currentProgress * 100).round().toDouble(),
          payload: NotificationPayload.progress(
              (currentProgress * 100).round(), totalRequests),
        ),
      );
    }

    // Request tatsächlich absenden
    try {
      final response = await API().remote.postJSON(requestData);
      if (response == null || (response.statusCode ~/ 100) != 2) {
        overallSuccess = false;
        debugPrint('Fehler beim Request (Status != 2xx), breche ab...');
        break;
      } else {
        API().local.failedRequestWasSuccessful(docID);
      }
    } catch (e) {
      overallSuccess = false;
      debugPrint('Fehler beim Hochladen: $e');
      break;
    }
  }

  // 10) Fortschritt auf 100% setzen, Upload abschließen
  uploadState.setProgress(1.0);
  uploadState.setSuccess(overallSuccess);
  uploadState.setLoading(false);
  input.progressSender.send((1.0, overallSuccess));

  // 11) Am Ende separate Notification für Erfolg/Fehlschlag
  if (input.notificationsAllowed && totalRequests > 0) {
    if (overallSuccess) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 2, // NEUE ID => separate Notification
          channelKey: 'progress',
          title: Emojis.symbols_check_mark_button + ' Upload Sync Done',
          body: 'Alle PjNr wurden erfolgreich hochsynchronisiert.',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.Default,
        ),
      );
    } else {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 3, // NEUE ID => separate Notification
          channelKey: 'progress',
          title: Emojis.symbols_cross_mark + ' Upload Sync Failed',
          body:
              'Einige Offline-Änderungen konnten nicht hochsynchronisiert werden.',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.Default,
        ),
      );
    }
  }
}

/// FailedRequestmanager
/// - Die `retryFailedrequests`-Methode startet entweder ein Isolate
///   oder ruft `_retryFailedRequestsIsolate` direkt auf.
class FailedRequestmanager {
  Future<bool> retryFailedrequests({
    required BuildContext context,
    void Function(double)? onProgress,
  }) async {
    debugPrint('Main: retryFailedRequests gestartet.');

    // 1) Check Netzwerk
    try {
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.PUT);
    } catch (e) {
      showToast(S.current!.noViableInternetConnection);
      return false;
    }

    // 2) Check Notification Permission
    bool notificationsAllowed = await allowNotificationGuard(
      context,
      S.of(context).weCanSendYouANotificationAboutTheSyncProgress,
    );

    // 3) ReceivePort anlegen, um Updates zu empfangen
    bool finalSuccess = false;
    final progressReceiver = ReceivePort();
    final isolateInputData = _RetryFailedRequestsIsolateInput(
      rootIsolateToken: RootIsolateToken.instance!,
      progressSender: progressReceiver.sendPort,
      notificationsAllowed: notificationsAllowed,
    );

    // Auf Nachrichten vom Isolate lauschen
    final sub = progressReceiver.listen((msg) {
      final (progress, maybeSuccess) = msg as (double, bool?);
      if (maybeSuccess != null) {
        // Wir sind fertig
        finalSuccess = maybeSuccess;
        progressReceiver.close();
      } else {
        // reiner Fortschrittswert
        onProgress?.call(progress);
      }
    });

    // 4) Isolate starten (oder direkt im Main-Thread ausführen)
    final runInIsolate = true;
    if (runInIsolate) {
      await Isolate.spawn(_retryFailedRequestsIsolate, isolateInputData);
    } else {
      await _retryFailedRequestsIsolate(isolateInputData);
    }

    // 5) Auf Abschluss warten
    await sub.asFuture();
    return finalSuccess;
  }

  /// Beispielhafte Methode zum rekursiven Cachen (unverändert)
  Future<bool> loadAndCacheAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    if (depth == 0) return true;
    depth--;

    try {
      await API().tryNetwork(requestType: Helper.SimulatedRequestType.GET);
      final children = await caller
          .all(preloadFullImages: Options().preloadFullImagesOnManualDownload)
          .last;
      if (caller.currentData is InspectionLocation) {
        final location = caller.currentData as InspectionLocation;
        if (location.dokuspaths != null && location.dokuspaths!.isNotEmpty) {
          var docus = location.dokuspaths;
          if (docus != null) {
            assert((await API().user) != null,
                S.current!.wontFetchAnythingSinceNoOneIsLoggedIn);
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

      final success = didSucceed.every((el) => el);
      if (success) {
        caller.currentData.forceOffline = true;
        if (parentID == null) return false;
        await API().local.storeData(caller.currentData, forId: parentID);
      }

      return success;
    } catch (error) {
      debugPrint('Fehler beim Laden/Cachen (Tiefe: ${depth + 1}): $error');
      showToast(error.toString() + "\n" + S.current!.tryAgainLater_noNetwork);
      return false;
    }
  }

  /// Setzt alles auf "Online" (Beispielmethode)
  Future<void> setOnlineTotal(BuildContext context) async {
    final model = Provider.of<LocationModel>(context, listen: false);
    final locations = await model.all().last;
    for (final loc in locations) {
      final caller = CategoryModel(loc);
      await setOnlineAll(caller, 3,
          name: caller.title, parentID: await API().rootID);
    }
  }

  Future<void> setOnlineAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    if (depth == 0) return;
    depth--;

    final children = await caller.all().last;
    caller.currentData.forceOffline = false;
    if (parentID != null) {
      await API().local.storeData(caller.currentData, forId: parentID);
    }
    final nextId = caller.currentData.id;

    for (final child in children) {
      if (depth == 0) return;
      setOnlineAll(
        caller.generateNextModel(child),
        depth,
        name: '$name -> ${child.title}',
        parentID: nextId,
      );
    }
  }
}
