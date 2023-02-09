import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class DefaultNotificationPage extends StatelessWidget {
  final ReceivedAction action;
  const DefaultNotificationPage({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Default Notification Page'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Default Notification Page'),
            Text('Payload: ${action.payload}'),
          ],
        ),
      ),
    );
  }
}
