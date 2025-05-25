part of 'controller.dart';

class ChannelController {
  List<NotificationChannel> channels = [
    NotificationChannel(
        channelKey: 'mbg_all_notifications',
        channelName: 'MBG App Benachrichtigungen',
        channelDescription: 'Alle Benachrichtigungen der MBG App',
        defaultColor: mbgpalette0,
        importance: NotificationImportance.Max,
        playSound: true,
        enableVibration: true,
        ledColor: Colors.blue),
  ];
}
