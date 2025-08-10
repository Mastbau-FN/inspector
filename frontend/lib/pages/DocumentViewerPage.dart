import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../backend/api.dart';

class DocumentViewerPage extends StatefulWidget {
  /// The Base64-encoded file data.

  /// The file name including its extension (e.g., "document.pdf", "report.docx").
  final String docupath;

  const DocumentViewerPage({
    Key? key,
    required this.docupath,
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
      // Fetch the Base64-encoded file from your API
      final file = await API().getDocument(widget.docupath);

      // Open the file with the native viewer.
      showToast(file!.path);
      final result = await OpenFile.open(file.path);
      debugPrint('OpenFile result: ${result.message}');

      setState(() {
        _isOpening = false;
        _message = 'Document opened. Please check your native viewer.';
      });
      if (result.type == ResultType.noAppToOpen) {
        setState(() {
          _isOpening = false;
          _message = 'Keine App zum Öffnen des Dokuments gefunden.';
        });
      }
    } catch (e) {
      debugPrint("Error opening document: $e");
      setState(() {
        _isOpening = false;
        _message = 'Failed to open document.';
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
