import 'dart:io';

import 'package:MBG_Inspektionen/pages/DocumentViewerPage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_file/open_file.dart';

void main() {
  test('forces chooser for modern Office documents only', () {
    expect(shouldForceDocumentOpenChooser('/tmp/report.docx'), isTrue);
    expect(shouldForceDocumentOpenChooser('/tmp/table.xlsx'), isTrue);
    expect(shouldForceDocumentOpenChooser('/tmp/report.pdf'), isFalse);
    expect(shouldForceDocumentOpenChooser('/tmp/legacy.doc'), isFalse);
  });

  test('uses Office mime types for docx and xlsx', () {
    expect(
      mimeTypeForDocumentPath('/tmp/report.docx'),
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    expect(
      mimeTypeForDocumentPath('/tmp/table.xlsx'),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  });

  test('opens docx through chooser instead of default app', () async {
    final file = await _tempFile('report.docx');
    final chooserCalls = <String>[];

    final result = await openDocumentFile(
      file,
      defaultOpener: (_, {type}) async {
        fail('docx must not use default opener');
      },
      chooserOpener: (path, mimeType, title) async {
        chooserCalls.add('$path|$mimeType|$title');
      },
    );

    expect(result.mode, DocumentOpenMode.chooser);
    expect(chooserCalls, hasLength(1));
    expect(chooserCalls.single, contains('report.docx'));
    expect(chooserCalls.single, contains('wordprocessingml.document'));
    expect(chooserCalls.single, contains('Dokument öffnen mit'));
  });

  test('opens pdf through default app', () async {
    final file = await _tempFile('plan.pdf');
    final defaultCalls = <String>[];

    final result = await openDocumentFile(
      file,
      defaultOpener: (path, {type}) async {
        defaultCalls.add('$path|$type');
        return OpenResult(message: 'done');
      },
      chooserOpener: (_, __, ___) async {
        fail('pdf must not use chooser opener');
      },
    );

    expect(result.mode, DocumentOpenMode.defaultApp);
    expect(defaultCalls, hasLength(1));
    expect(defaultCalls.single, contains('plan.pdf'));
    expect(defaultCalls.single, contains('application/pdf'));
  });
}

Future<File> _tempFile(String name) async {
  final dir = await Directory.systemTemp.createTemp('document_viewer_test_');
  addTearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  final file = File('${dir.path}/$name');
  await file.writeAsBytes([1, 2, 3]);
  return file;
}
