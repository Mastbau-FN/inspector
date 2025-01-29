import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:win32/win32.dart';
import '../main.dart';
import '../theme.dart';

part 'channels.dart';

class NotificationPayload {
  static Map<String, String?>? progress(int progress, num max) {
    return {
      'type': 'progress',
      'title': 'Upload Sync in Progress',
      'progress': progress.toString(),
      'max': max.toString(),
    };
  }

  static Map<String, String?>? done() {
    return {
      'type': 'done',
      'title': 'Upload Sync Done',
    };
  }

  static Map<String, String?>? failed(RequestData? requestData) {
    return {
      'type': 'failed',
      'title': 'Upload Sync Failed',
      'requestData': requestData?.toString(),
    };
  }
}

/// This class is used to control the notifications
// Kontroller für Notifications. Ruft Methoden von Awesome Notifications auf.
class NotificationController {
  static initialize() {
    AwesomeNotifications().initialize(
      'resource://drawable/ic_icon',
      ChannelController().channels,
      debug: kDebugMode,
    );
  }

  static initListeners() {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    // ...
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    // ...
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // ...
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // ...
    // Beispiel: bei Tap -> eine bestimmte Seite öffnen
    MyApp.navigatorKey.currentState?.pushNamed(
      '/default-notification-page',
      arguments: receivedAction,
    );
  }
}

/// Fragt den Nutzer, ob er Benachrichtigungen zulassen möchte.
Future<bool> allowNotificationGuard(BuildContext context, String reason) async {
  if (await AwesomeNotifications().isNotificationAllowed()) {
    return true;
  } else {
    bool? willAsk = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).allowNotifications),
        content: Text(reason),
        actions: [
          TextButton(
            child: Text(S.of(context).cancel),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text(S.of(context).allow),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (willAsk == true) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
      // Nochmal prüfen
      return await allowNotificationGuard(
        context,
        S.of(context).didYouMisclick + ' ' + reason,
      );
    } else {
      return false;
    }
  }
}
