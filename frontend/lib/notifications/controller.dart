import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';
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
}

/// This class is used to control the notifications
class NotificationController {
  static initialize() {
    AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
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
        onDismissActionReceivedMethod: onDismissActionReceivedMethod);
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    // Your code goes here
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    // Your code goes here
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // Your code goes here
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // Your code goes here

    // Navigate into pages, avoiding to open the notification details page over another details page already opened
    MyApp.navigatorKey.currentState
        ?.pushNamed /*AndRemoveUntil*/ ('/default-notification-page',
            // (route) =>
            //     (route.settings.name != '/default-notification-page') ||
            //     route.isFirst,
            arguments: receivedAction);
  }
}

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
                  onPressed: () async {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            ));
    if (willAsk == true) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
      return await allowNotificationGuard(
          context, S.of(context).didYouMisclick + ' ' + reason);
    } else {
      return false;
    }
  }
}
