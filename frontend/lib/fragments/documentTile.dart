import 'dart:io';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

class DocumentTile<T extends Object> extends StatelessWidget {
  final DocumentData<T> document;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const DocumentTile({
    required this.document,
    required this.onDelete,
    required this.onShare,
  });

  void openDocument() {
    OpenFile.open(document.preview.path);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: openDocument,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insert_drive_file, size: 50),
            Text(document.preview.path.split('/').last),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(icon: Icon(Icons.delete), onPressed: onDelete),
                IconButton(icon: Icon(Icons.share), onPressed: onShare),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
