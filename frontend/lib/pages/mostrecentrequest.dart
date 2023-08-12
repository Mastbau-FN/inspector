import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/material.dart';

class MostRecentRequestPage extends StatelessWidget {
  const MostRecentRequestPage({super.key, required this.request});

  final (String, RequestData?)? request;

  @override
  Widget build(BuildContext context) {
    if (request == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('No Request'),
        ),
        body: Center(
          child: Text('No Request'),
        ),
      );
    }
    final (String id, RequestData? data) = request!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Most Recent Request: $id'),
      ),
      body: ListView(
        // mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data == null)
            Text('No Data')
          else ...[
            Text('Route: \n${data.route}'),
            Divider(),
            Text('Data: \n${data.json}'),
            Divider(),
            if (data.multipartFiles.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var ffile in data.multipartFiles)
                      FutureBuilder(
                          future: ffile,
                          builder: (context, snap) {
                            if (!snap.hasData)
                              return CircularProgressIndicator();
                            final file = snap.data!;
                            return Column(
                              children: [
                                Text('File: ${file.name}'),
                                FutureBuilder(
                                  future: file.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(snapshot.data!);
                                    } else {
                                      return CircularProgressIndicator();
                                    }
                                  },
                                )
                              ],
                            );
                          }),
                  ],
                ),
              ),
            Row(children: [
              TextButton(
                onPressed: () async {
                  await API().local.failedRequestWasSuccessful(id);
                  showToast('Request was successfully deleted');
                  Navigator.pop(context);
                },
                child: Text('Skip & Delete'),
                //red style
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ])
          ],
        ],
      ),
    );
  }
}
