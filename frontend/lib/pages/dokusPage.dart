import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'DocumentViewerPage.dart';

class DokusList extends StatelessWidget {
  final List<DocumentData>? dokus;

  const DokusList({Key? key, this.dokus}) : super(key: key);

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dokus'),
      ),
      body: ListView.builder(
        itemCount: dokus!.length,
        itemBuilder: (context, index) {
          return Card(
            margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              title: Text(
                dokus![index].filename,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(Icons.insert_drive_file, color: Colors.blueGrey),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerPage(
                      docupath: dokus![index].docupath,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
