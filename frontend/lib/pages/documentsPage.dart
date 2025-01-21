import 'dart:io';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:MBG_Inspektionen/fragments/documentWrap.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:MBG_Inspektionen/fragments/MainDrawer.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

class DocumentsPage<T extends Object> extends StatelessWidget {
  late final List<Stream<DocumentData<T>?>> _documents;
  final Future<String?> Function(List<File>) onNewDocuments;
  final int columnCount;

  static Future<String?> _defaultAdd(List<File> list) async {
    showToast("Not available.");
    return "";
  }

  static _default(Object _) => showToast("Not available.");

  final Function(T) onDelete;
  final Function(T) onShare;

  DocumentsPage.constant({
    List<DocumentData<T>?>? documents = const [],
    this.columnCount = 2,
    Key? key,
    this.onNewDocuments = _defaultAdd,
    this.onDelete = _default,
    this.onShare = _default,
  }) : super(key: key) {
    this._documents =
        documents?.whereNotNull().map((e) => Stream.value(e)).toList() ?? [];
  }

  DocumentsPage.futured({
    List<Future<DocumentData<T>?>>? futureDocuments = const [],
    this.columnCount = 2,
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
    this.columnCount = 2,
    Key? key,
    this.onNewDocuments = _defaultAdd,
    this.onDelete = _default,
    this.onShare = _default,
  }) : super(key: key) {
    this._documents = documentStreams ?? [];
  }

  final FilePicker _picker = FilePicker.platform;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          endDrawer: MainDrawer(),
          appBar: AppBar(
            title: Text('Dokumente'),
          ),
          body: DocumentWrap<T>.streamed(
            documents: _documents,
            onDelete: onDelete,
            onShare: onShare,
          ),
        ),
        ChangeNotifierProvider(
          create: (ocontext) => DocumentPickerModel(),
          child: Builder(builder: (context) {
            return DocumentAddButton(
              picker: _picker,
              onNewDocuments: onNewDocuments,
            );
          }),
        ),
      ],
    );
  }
}

class DocumentPickerModel extends ChangeNotifier {
  List<File> _selectedDocuments = [];

  List<File> get selectedDocuments => _selectedDocuments;

  Future<void> pickDocuments() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      _selectedDocuments = result.paths
          .map((path) => File(path!))
          .toList(); // Convert paths to Files
      notifyListeners(); // Notify listeners about the document changes
    }
  }
}

class DocumentAddButton extends StatefulWidget {
  const DocumentAddButton({
    Key? key,
    required FilePicker picker,
    required this.onNewDocuments,
  })  : _picker = picker,
        super(key: key);

  final FilePicker _picker;
  final Future<String?> Function(List<File> p1) onNewDocuments;

  @override
  State<DocumentAddButton> createState() => _DocumentAddButtonState();
}

class _DocumentAddButtonState extends State<DocumentAddButton> {
  bool uploadingDocument = false;

  @override
  Widget build(BuildContext ocontext) {
    return addDocumentButton();
  }

  Widget addDocumentButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: uploadFromSystem,
        ),
      ),
    );
  }

  void uploadFromSystem() async {
    FilePickerResult? result = await widget._picker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      List<File> files = result.paths.map((path) => File(path!)).toList();
      var resstring = await widget.onNewDocuments(files);
      showToast(resstring ?? "Upload completed.");
    }
  }
}
