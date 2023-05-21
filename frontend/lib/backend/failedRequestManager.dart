import 'dart:async';
import 'dart:isolate';

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

void _retryFailedRequestsIsolate(_RetryFailedRequestsIsolateInput input) async {
  if (!kIsWeb) {
    // Register the background isolate with the root isolate.
    BG.initialize(input.rootIsolateToken);
  }

  final failedReqs = await API().local.getAllFailedRequests() ?? [];
  DisplayUser? user = await API()
      .user; //! do not remove this otherwise everything falls apart no idea why ; jk it's because the user is not set in the isolate remote, and calling API().user will inject it
  if (user == null) {
    input.progressSender.send((1.0, false));
    return;
  }
  bool success = true;
  num total = failedReqs.length;

  input.progressSender.send((0.0, null));

  final lastStep = DateTime.fromMillisecondsSinceEpoch(0);
  for (var i = 0; i < total; i++) {
    input.progressSender.send(((i / total), null));
    if (DateTime.now().difference(lastStep).inSeconds >= 1) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
            id: 1,
            channelKey: 'progress',
            title: 'Upload Sync',
            body: 'Offline Änderungen werden hochsynchronisiert...',
            category: NotificationCategory.Progress,
            notificationLayout: NotificationLayout.ProgressBar,
            progress: (i / total * 100).round(),
            // locked: true,
            payload: NotificationPayload.progress(i, total)),
      );
    }
    final (docID, rd) = failedReqs[i];
    if (rd != null) {
      try {
        debugPrint('retry request $i/$total: ${rd.route}');
        rd.logIfFailed = false;
        final res = await API().remote.postJSON(rd);
        //nur 200er als ok einstufen
        if (res!.statusCode ~/ 100 == 2) {
          API().local.failedRequestWasSuccessful(docID);
        } else {
          success = false;
          //TODO: what todo here?
          AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: 1,
              channelKey: 'progress',
              title: Emojis.symbols_cross_mark + ' ' + 'Upload Sync Failed',
              body:
                  'Offline Änderungen konnten NICHT(!) hochsynchronisiert werden.. probiers nochmal oder melde dich beim Support',
              category: NotificationCategory.Progress,
              notificationLayout: NotificationLayout.ProgressBar,
              progress: (i / total * 100).round(),
              payload: NotificationPayload.failed(rd),
              // locked: false,
            ),
          );
          break;
        }
      } catch (e) {
        debugPrint('failed to retry request: $e');
        success = false;
      }
    }
  }
  if (input.notificationsAllowed && success) {
    //TODO: play sound
    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'progress',
        title: Emojis.symbols_check_mark_button + ' ' + 'Upload Sync Done',
        body: 'Offline Änderungen wurden hochsynchronisiert',
        category: NotificationCategory.Progress,
        notificationLayout: NotificationLayout.ProgressBar,
        progress: 100,
        payload: NotificationPayload.done(),
        // locked: false,
      ),
    );
  }
  input.progressSender.send((1.0, success));
}

class _RetryFailedRequestsIsolateInput {
  final RootIsolateToken rootIsolateToken;
  final API api;
  final SendPort progressSender;
  final bool notificationsAllowed;
  const _RetryFailedRequestsIsolateInput({
    required this.rootIsolateToken,
    required this.api,
    required this.progressSender,
    this.notificationsAllowed = false,
  });
}

class FailedRequestmanager {
  Future<bool> retryFailedrequests(
      {required BuildContext context,
      void Function(double)? onProgress}) async {
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
    ReceivePort progressReceiver = ReceivePort();
    var isolateInputData = _RetryFailedRequestsIsolateInput(
      rootIsolateToken: RootIsolateToken.instance!,
      api: API(),
      progressSender: progressReceiver.sendPort,
      notificationsAllowed: notificationsAllowed,
    );

    final ss = progressReceiver.listen((msg) {
      final (progress, _success) = msg as (double, bool?);
      if (_success != null) {
        success = _success;
        progressReceiver.close();
      } else {
        onProgress?.call(progress);
      }
    }); // as StreamSubscription<(double, bool)>;

    // ss.
    if (!kIsWeb)
      await Isolate.spawn(_retryFailedRequestsIsolate, isolateInputData);
    else
      _retryFailedRequestsIsolate(isolateInputData);

    await ss.asFuture();

    return success;
  }

  /// recursivle cache all elements that underly the caller
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
      showToast(error.toString() + "\n" + S.current!.tryAgainLater_noNetwork);
      return false; //failed
    }
  }

  ///this is used to remove all no-cloud icons from every datapoint aka set every [forceOffline] of [WithOffline] [Data]s
  setOnlineTotal(BuildContext context) async {
    final model = Provider.of<LocationModel>(context, listen: false);
    final locations = await model.all().last;
    for (final loc in locations) {
      final caller = CategoryModel(loc);
      await setOnlineAll(
        caller,
        3,
        name: caller.title,
        parentID: await API().rootID,
      );
    }
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
    // base-case: CheckPointDefects have no children
    if (depth == 0) return true;
    depth--;
    var children = await caller.all().last;
    caller.currentData.forceOffline = false;
    if (parentID != null)
      API().local.storeData(caller.currentData, forId: parentID);
    final nextid = caller.currentData.id;
    for (final child in children) {
      String _name = '$name -> ${child.title}';
      debugPrint('__12342 got $depth: $_name');
      if (depth == 0) return; //base-case as to not call generateNextModel
      setOnlineAll(caller.generateNextModel(child), depth,
          name: _name, parentID: nextid);
    }
  }
}

// class NewImages /*extends Map<String, String?>*/ {
//   factory NewImages() => _instance;
//   static final NewImages _instance = NewImages._internal();
//   NewImages._internal() {
//     load();
//   }

//   static Map<String, dynamic> localImageToRemoteImage_ = {};
//   static Future<Map<String, dynamic>> get() async {
//     // await load();
//     return localImageToRemoteImage_;
//   }

//   static set(Map<String, String?> map) async {
//     localImageToRemoteImage_ = map;
//     await store();
//   }

//   static add(String local, String remote) => addAll({local: remote});

//   static remove(String local) async {
//     // await load();
//     localImageToRemoteImage_.remove(local);
//     await store();
//   }

//   static clear() async {
//     localImageToRemoteImage_.clear();
//     await store();
//   }

//   static addAll(Map<String, String?> map) async {
//     // await load();
//     localImageToRemoteImage_.addAll(map);
//     await store();
//   }

//   static addAllNulled(List<String> l) => addAll({for (var e in l) e: null});

//   static const _IMGDOC_ = '__localImageToRemoteImageMap__';
//   static store() => storeJson(_IMGDOC_, localImageToRemoteImage_);
//   static load() async {
//     final json = await getJson(_IMGDOC_);
//     debugPrint('loaded: $json');
//     localImageToRemoteImage_ = json ?? {};
//   }
// }

// abstract interface class ProgressReseivePort implements ReceivePort {
//   ProgressReseivePort() : super();
//   @override
//   SendPort get sendPort => ProgressSendPort();
// }

// abstract interface class ProgressSendPort implements SendPort {
//   ProgressSendPort() : super();

//   void send((double, bool?) message) => super.send(message);
// }
