import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../classes/documentData.dart';

class DocumentsPage<T extends Object> extends StatelessWidget {
  late final List<Stream<DocumentData<T>?>> _documents;
  final Future<String?> Function(List<XFile>) onNewDocuments;
  final Function(T) onDelete;
  final Function(T) onShare;

  static Future<String?> _defaultAdd(List<XFile> list) async {
    debugPrint("Add new documents not available.");
    return null;
  }

  static _default(Object _) {
    debugPrint("Operation not available.");
  }

  DocumentsPage.constant({
    List<DocumentData<T>?>? documents = const [],
    Key? key,
    this.onNewDocuments = _defaultAdd,
    this.onDelete = _default,
    this.onShare = _default,
  }) : super(key: key) {
    this._documents = documents
            ?.whereType<DocumentData<T>>()
            .map((e) => Stream.value(e))
            .toList() ??
        [];
  }

  DocumentsPage.futured({
    List<Future<DocumentData<T>?>>? futureDocuments = const [],
    Key? key,
    this.onNewDocuments = _defaultAdd,
    this.onDelete = _default,
    this.onShare = _default,
  }) : super(key: key) {
    this._documents =
        futureDocuments?.map((e) => Stream.fromFuture(e)).toList() ?? [];
  }

  DocumentsPage.streamed({
    List<Stream<DocumentData<T>?>>? documentStreams = const [],
    Key? key,
    this.onNewDocuments = _defaultAdd,
    this.onDelete = _default,
    this.onShare = _default,
  }) : super(key: key) {
    this._documents = documentStreams ?? [];
  }

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white, // Set white background
          appBar: AppBar(
            title: const Text("Dokumente"),
          ),
          body: DocumentWrap<T>.streamed(
            documents: _documents,
            onDelete: onDelete,
            onShare: onShare,
          ),
        ),
        DocumentAddButton(
          picker: _picker,
          onNewDocuments: onNewDocuments,
        ),
      ],
    );
  }
}

class DocumentWrap<T extends Object> extends StatelessWidget {
  final List<Stream<DocumentData<T>?>> documents;
  final Function(T) onDelete;
  final Function(T) onShare;

  const DocumentWrap.streamed({
    required this.documents,
    required this.onDelete,
    required this.onShare,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentData<T>?>>(
      stream: Stream.fromIterable(documents)
          .asyncMap((stream) => stream.last)
          .toList()
          .asStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;
        debugPrint("DocumentWrap: ${docs.length} documents");

        //10 Dokumente kommen an aber ohne Daten
        return Container(
          color: Colors.white, // Ensure background stays white
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final docData = docs[index];
              debugPrint("DocumentWrap: Document $index: $docData");
              if (docData == null) return const SizedBox.shrink();

              return ListTile(
                tileColor: Colors.white, // Ensure each row is white
                leading: const Icon(Icons.description),
                title: Text("Dokument: ${docData.id}"),
                subtitle: const Text(
                  "Tippen zum Öffnen. Langdruck zum Teilen?",
                  style: TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  final file = await docData.fullDocument();
                  if (file != null) {
                    debugPrint("Opening file: ${file.path}");
                  }
                },
                onLongPress: () async {
                  onShare(docData.id as T);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        onDelete(docData.id as T);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        onShare(docData.id as T);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class DocumentAddButton extends StatelessWidget {
  final ImagePicker picker;
  final Future<String?> Function(List<XFile>) onNewDocuments;

  const DocumentAddButton({
    Key? key,
    required this.picker,
    required this.onNewDocuments,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton(
          child: const Icon(Icons.add),
          onPressed: () async {
            final List<XFile>? newDocuments = await picker.pickMultiImage();
            if (newDocuments != null && newDocuments.isNotEmpty) {
              final result = await onNewDocuments(newDocuments);
              debugPrint("Document upload result: $result");
            }
          },
        ),
      ),
    );
  }
}
