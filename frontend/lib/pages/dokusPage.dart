import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:flutter/material.dart';

import 'DocumentViewerPage.dart';

class DokusList extends StatelessWidget {
  final List<DocumentData>? dokus;

  const DokusList({Key? key, this.dokus}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dokus'),
      ),
      body: ListView.builder(
        shrinkWrap: true,
        itemCount: dokus!.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              dokus![index].name,
            ), // Zeigt nur den Dateinamen an
            trailing: Icon(Icons.insert_drive_file),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DocumentViewerPage(
                      base64Data: dokus![index].content,
                      fileName: dokus![index].name),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
