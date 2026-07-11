import 'dart:io';

import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

import '../backend/api.dart';

const MethodChannel _documentChooserChannel =
    MethodChannel('mbg/open_document_chooser');

enum DocumentOpenMode { chooser, defaultApp, noApp }

class DocumentOpenResult {
  final DocumentOpenMode mode;
  final String message;

  const DocumentOpenResult(this.mode, this.message);
}

bool shouldForceDocumentOpenChooser(String path) {
  final extension = _extensionFromPath(path);
  return extension == 'docx' || extension == 'xlsx';
}

String? mimeTypeForDocumentPath(String path) {
  switch (_extensionFromPath(path)) {
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'pdf':
      return 'application/pdf';
    default:
      return null;
  }
}

String _extensionFromPath(String path) {
  final base = path.split('/').last.split('?').first.toLowerCase();
  final index = base.lastIndexOf('.');
  if (index < 0 || index == base.length - 1) return '';
  return base.substring(index + 1);
}

Future<DocumentOpenResult> openDocumentFile(
  File file, {
  Future<OpenResult> Function(String path, {String? type})? defaultOpener,
  Future<void> Function(String path, String mimeType, String title)?
      chooserOpener,
}) async {
  final path = file.path;
  final mimeType = mimeTypeForDocumentPath(path);
  final opener = defaultOpener ?? OpenFile.open;

  if (shouldForceDocumentOpenChooser(path)) {
    try {
      final chooser = chooserOpener ?? _openWithAndroidChooser;
      await chooser(
        path,
        mimeType ?? 'application/octet-stream',
        'Dokument öffnen mit',
      );
      return const DocumentOpenResult(
        DocumentOpenMode.chooser,
        'Dokumentauswahl geöffnet.',
      );
    } on MissingPluginException {
      final result = await opener(path, type: mimeType);
      return _resultFromOpenFile(result);
    } on PlatformException catch (error) {
      if (error.code == 'NO_APP') {
        return const DocumentOpenResult(
          DocumentOpenMode.noApp,
          'Keine App zum Öffnen des Dokuments gefunden.',
        );
      }
      rethrow;
    }
  }

  final result = await opener(path, type: mimeType);
  return _resultFromOpenFile(result);
}

Future<void> _openWithAndroidChooser(
  String path,
  String mimeType,
  String title,
) async {
  await _documentChooserChannel.invokeMethod<void>(
    'openWithChooser',
    {
      'path': path,
      'mimeType': mimeType,
      'title': title,
    },
  );
}

DocumentOpenResult _resultFromOpenFile(OpenResult result) {
  if (result.type == ResultType.noAppToOpen) {
    return const DocumentOpenResult(
      DocumentOpenMode.noApp,
      'Keine App zum Öffnen des Dokuments gefunden.',
    );
  }
  return DocumentOpenResult(
    DocumentOpenMode.defaultApp,
    result.message.isEmpty
        ? 'Document opened. Please check your native viewer.'
        : result.message,
  );
}

class DocumentViewerPage extends StatefulWidget {
  /// The Base64-encoded file data.

  /// The file name including its extension (e.g., "document.pdf", "report.docx").
  final String docupath;
  final String? scope;

  const DocumentViewerPage({
    Key? key,
    required this.docupath,
    this.scope,
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
      final file =
          await API().getDocument(widget.docupath, scope: widget.scope);

      if (file == null || !await file.exists()) {
        throw StateError('Document not cached');
      }

      showToast(file.path);
      final result = await openDocumentFile(file);
      debugPrint('Document open result: ${result.mode} ${result.message}');

      setState(() {
        _isOpening = false;
        _message = result.message;
      });
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
