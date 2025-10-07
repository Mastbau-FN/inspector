part of 'controller.dart';

class ChannelController {
  List<NotificationChannel> channels = [
    NotificationChannel(
        channelGroupKey: 'mbg_retryfailed_group',
        channelKey: 'progress',
        channelName: 'Progress',
        channelDescription: 'Shows the progress of the upload sync',
        defaultColor: mbgpalette0,
        ledColor: Colors.white)
  ];
}
