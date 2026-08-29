import 'package:MBG_Inspektionen/backend/image_naming.dart';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:flutter/material.dart';
import 'DocumentViewerPage.dart';

class DokusList extends StatelessWidget {
  final List<DocumentData>? dokus;
  final String? scope;

  const DokusList({Key? key, this.dokus, this.scope}) : super(key: key);

  Widget build(BuildContext context) {
    final docs = (dokus ?? const <DocumentData>[])
        .where((document) =>
            !isKnownServerArtifactFilename(document.filename) &&
            !isKnownServerArtifactFilename(document.docupath))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Dokus'),
      ),
      body: docs.isEmpty
          ? Center(
              child: Text(
                'Keine Dokus vorhanden',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    title: Text(
                      docs[index].filename,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing:
                        Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentViewerPage(
                            docupath: docs[index].docupath,
                            scope: scope,
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
