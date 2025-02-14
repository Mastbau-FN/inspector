import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class DocumentViewerPage extends StatefulWidget {
  /// The Base64-encoded file data.
  final String base64Data;

  /// The file name including its extension (e.g., "document.pdf", "report.docx").
  final String fileName;

  const DocumentViewerPage({
    Key? key,
    required this.base64Data,
    required this.fileName,
  }) : super(key: key);

  @override
  _DocumentViewerPageState createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  bool _isOpening = true;
  String _message = 'Opening document...';

  @override
  void initState() {
    super.initState();
    _openDocument();
  }

  Future<void> _openDocument() async {
    try {
      // Decode the Base64 string into bytes.
      final bytes = base64Decode(widget.base64Data);

      // Get the temporary directory.
      final dir = await getTemporaryDirectory();

      // Create a file with the given name in the temporary directory.
      final file = File('${dir.path}/${widget.fileName}');

      // Write the bytes to the file.
      await file.writeAsBytes(bytes);

      // Open the file with the native viewer.
      final result = await OpenFile.open(file.path);
      debugPrint('OpenFile result: ${result.message}');

      // Optionally, you could update the UI depending on result.
      setState(() {
        _isOpening = false;
        _message = 'Document opened. Please check your native viewer.';
      });
    } catch (e) {
      debugPrint("Error opening document: $e");
      setState(() {
        _isOpening = false;
        _message = 'You have no app that can open this document.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Viewer')),
      body: Center(
        child: _isOpening ? const CircularProgressIndicator() : Text(_message),
      ),
    );
  }
}
