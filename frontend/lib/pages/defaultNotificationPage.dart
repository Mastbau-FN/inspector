import 'package:MBG_Inspektionen/backend/progressStateUpdater.dart';
import 'package:MBG_Inspektionen/pages/settings/settingsView.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DefaultNotificationPage extends StatelessWidget {
  final ReceivedAction action;
  const DefaultNotificationPage({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    // Debug-Ausgabe zur Nachverfolgung der Benachrichtigungsdetails
    debugPrint(
        'DefaultNotificationPage: Received action with ID=${action.id}, Channel=${action.channelKey}');
    debugPrint('Payload: ${action.payload}');

    String title;
    Widget contentWidget;

    if (action.id == 900) {
      // Sync Start Benachrichtigung
      title = '🔄 Upload Sync gestartet';
      contentWidget = Column(
        children: [
          Text('Die Synchronisierung wurde gestartet'),
          SizedBox(height: 20),
          CircularProgressIndicator(),
        ],
      );
    } else if (action.id == 999) {
      // Sync Success Benachrichtigung
      title = '✅ Upload Sync Done';
      contentWidget = Column(
        children: [
          Text('Die Synchronisierung wurde erfolgreich abgeschlossen'),
          SizedBox(height: 10),
          Icon(Icons.check_circle, size: 50, color: Colors.green),
        ],
      );
    } else if (action.id == 997) {
      // Sync Error Benachrichtigung
      title = '❌ Upload Sync Failed';
      contentWidget = Column(
        children: [
          Text('Bei der Synchronisierung ist ein Fehler aufgetreten'),
          SizedBox(height: 10),
          Icon(Icons.error, size: 50, color: Colors.red),
        ],
      );
    } else if (action.id == 888) {
      // Progress Benachrichtigung
      title = 'Upload Sync läuft...';

      // Hier den aktuellen Fortschritt aus dem Provider anzeigen
      contentWidget = Column(
        children: [
          Text('Synchronisierung läuft...'),
          SizedBox(height: 20),
          ChangeNotifierProvider(
            create: (_) => ProgressStateUpdater(),
            child: Builder(
              builder: (context) {
                final actualProgress =
                    context.watch<ProgressStateUpdater>().progress;
                return Column(
                  children: [
                    Text(
                        'Fortschritt: ${((actualProgress ?? 0) * 100).toStringAsFixed(1)}%'),
                    SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: actualProgress ?? 0,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    } else {
      // Standard-Fallback für andere Benachrichtigungen
      title = action.payload?['title'] ?? 'Benachrichtigung';

      // Ursprüngliche Logik beibehalten
      contentWidget = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: action.payload?['type'] == 'done'
            ? [
                Text('Upload Sync Done'),
                Icon(Icons.check, size: 50),
              ]
            : action.payload?['type'] == 'progress'
                ? [
                    Text('Upload Sync in Progress'),
                    Text(
                        '${action.payload!['progress']} / ${action.payload!['max']}'),
                    LinearProgressIndicator(
                      value: int.tryParse(action.payload!['progress']!)! /
                          int.tryParse(action.payload!['max']!)!,
                    ),
                    SizedBox(height: 20),
                    ChangeNotifierProvider(
                      create: (_) => ProgressStateUpdater(),
                      child: Builder(
                        builder: (context) {
                          final actualProgress =
                              context.watch<ProgressStateUpdater>().progress;
                          return switch (actualProgress) {
                            null => CircularProgressIndicator(),
                            double p => LinearProgressIndicator(value: p),
                          };
                        },
                      ),
                    ),
                  ]
                : action.payload?['type'] == 'failed'
                    ? [
                        Text('Upload Sync Failed'),
                        Text('Request Data: ${action.payload!['requestData']}'),
                        Icon(Icons.error, size: 50),
                      ]
                    : [
                        Text('Default Notification Page'),
                        Text('Payload: ${action.payload}'),
                      ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              contentWidget,
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Zurück'),
              ),
              SizedBox(height: 20),
              OpenNextRequestTile(),
            ],
          ),
        ),
      ),
    );
  }
}
