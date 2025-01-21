import 'dart:io';

class DocumentData<T extends Object> {
  final File preview; // Represents a small version or metadata of the document.
  Future<File?> fullDocument() =>
      fullDocumentGetter?.call() ?? Future.value(preview);
  late final Future<File?> Function()? fullDocumentGetter;
  final T id;

  DocumentData(
    this.preview, {
    required this.id,
    this.fullDocumentGetter,
  });
}