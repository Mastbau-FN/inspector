import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:MBG_Inspektionen/fragments/documentTile.dart';
import 'package:flutter/material.dart';

class DocumentWrap<T  extends Object> extends StatelessWidget {
  final List<Stream<DocumentData<T>?>> documents;
  final Function(T) onDelete;
  final Function(T) onShare;

  const DocumentWrap.streamed({
    required this.documents,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        return StreamBuilder<DocumentData<T>?>(
          stream: documents[index],
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();

            DocumentData<T>? docData = snapshot.data;
            if (docData == null) return SizedBox.shrink();

            return DocumentTile(
              document: docData,
              onDelete: () => onDelete(docData.id),
              onShare: () => onShare(docData.id),
            );
          },
        );
      },
    );
  }
}