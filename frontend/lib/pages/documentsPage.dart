import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../classes/documentData.dart';

// If you want to open files with e.g. open_file or share_plus, import them:
// import 'package:open_file/open_file.dart';
// import 'package:share_plus/share_plus.dart';

class DocumentsPage extends StatelessWidget {
  final List<Future<DocumentData?>> futureDocuments;

  /// Called when user taps a button to add new documents (if you want that).
  final FutureOr<String?> Function(List<XFile> files)? onNewDocuments;

  /// Called when user taps “delete” on a document.
  final FutureOr<String?> Function(String hash)? onDelete;

  /// Called when user taps “share” on a document.
  final FutureOr<void> Function(String hash)? onShare;

  /// If your backend supports an "open" or "download" approach, you can unify with `onOpen`.
  // final FutureOr<void> Function(String hash)? onOpen;

  const DocumentsPage.futured({
    Key? key,
    required this.futureDocuments,
    this.onNewDocuments,
    this.onDelete,
    this.onShare,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1) we gather all future docs
    return FutureBuilder<List<DocumentData?>>(
      future: Future.wait(futureDocuments),
      builder: (context, snapshot) {
        // 2) basic error/loading handling
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Keine Dokumente gefunden."));
        }

        // 3) we have docs
        final docs = snapshot.data!;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final docData = docs[index];
            if (docData == null) return const SizedBox.shrink();

            return ListTile(
              leading: const Icon(Icons.description),
              title: Text("Dokument: ${docData.id}"),
              subtitle: Text(
                "Tippen zum Öffnen. Langdruck zum Teilen?",
                style: TextStyle(fontSize: 12),
              ),
              onTap: () async {
                // if you have an "open" approach:
                final file = await docData.fullDocument();
                if (file != null) {
                  // e.g. open_file
                  // OpenFile.open(file.path);

                  // or do a “Share”:
                  // await Share.shareXFiles([XFile(file.path)], text: 'Dokument');
                }
              },
              onLongPress: () async {
                if (onShare != null) {
                  onShare!(docData.id.toString());
                }
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        onDelete!(docData.id.toString());
                      },
                    ),
                  // optionally a share icon
                  if (onShare != null)
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () {
                        onShare!(docData.id.toString());
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
