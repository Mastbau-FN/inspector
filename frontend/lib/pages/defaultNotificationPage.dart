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
    return Scaffold(
      appBar: AppBar(
        title: Text(action.payload?['title'] ?? 'Nothing to See Here'),
      ),
      body: Center(
        child: Column(
          children: [
            Column(
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
                                final actualProgress = context
                                    .watch<ProgressStateUpdater>()
                                    .progress;
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
                              Text(
                                  'Request Data: ${action.payload!['requestData']}'),
                              Icon(Icons.error, size: 50),
                            ]
                          : [
                              Text('Default Notification Page'),
                              Text('Payload: ${action.payload}'),
                            ],
            ),
            OpenNextRequestTile(),
          ],
        ),
      ),
    );
  }
}
