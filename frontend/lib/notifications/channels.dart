part of 'controller.dart';

class ChannelController {
  List<NotificationChannel> channels = [
    NotificationChannel(
        channelGroupKey: 'mbg_retryfailed_group',
        channelKey: 'progress',
        channelName: 'Sync Fortschritt (lautlos)',
        channelDescription: 'Zeigt den Fortschritt der Synchronisation an',
        defaultColor: mbgpalette0,
        importance: NotificationImportance.None,
        playSound: false,
        enableVibration: false,
        ledColor: Colors.transparent),
    NotificationChannel(
        channelGroupKey: 'mbg_retryfailed_group',
        channelKey: 'backup_progress',
        channelName: 'Backup Fortschritt (lautlos)',
        channelDescription: 'Zeigt den Fortschritt des Backup-Prozesses an',
        defaultColor: mbgpalette0,
        importance: NotificationImportance.None,
        playSound: false,
        enableVibration: false,
        ledColor: Colors.transparent),
    NotificationChannel(
        channelGroupKey: 'mbg_retryfailed_group',
        channelKey: 'sync_complete',
        channelName: 'Sync Abschluss (mit Ton)',
        channelDescription:
            'Benachrichtigt über den Abschluss der Synchronisation',
        defaultColor: Colors.green,
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
        ledColor: Colors.green),
  ];
}
