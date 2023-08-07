import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter/material.dart';

class MostRecentRequestPage extends StatelessWidget {
  const MostRecentRequestPage({super.key, required this.request});

  final (String, RequestData?) request;

  @override
  Widget build(BuildContext context) {
    final (String id, RequestData? data) = request;

    return Scaffold(
      appBar: AppBar(
        title: Text('Most Recent Request: $id'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (data == null)
              Text('No Data')
            else ...[
              Text('Route: ${data.route}'),
              Text('Data: ${data.json}'),
              if (data.multipartFiles.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var file in data.multipartFiles)
                        Column(
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
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
