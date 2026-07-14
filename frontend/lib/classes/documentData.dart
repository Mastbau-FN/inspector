import 'package:json_annotation/json_annotation.dart';
part 'documentData.g.dart';

@JsonSerializable()
class DocumentData {
  final String filename;
  final String docupath; // Base64

  DocumentData({required this.filename, required this.docupath});

  factory DocumentData.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    final path = normalized['docupath'] ??
        normalized['docuPath'] ??
        normalized['DocuPath'] ??
        normalized['docPath'] ??
        normalized['path'];
    if (path != null) normalized['docupath'] = path.toString();

    final filename = normalized['filename'] ??
        normalized['fileName'] ??
        normalized['Filename'] ??
        normalized['name'];
    if (filename != null) {
      normalized['filename'] = filename.toString();
    } else if (normalized['docupath'] != null) {
      normalized['filename'] = normalized['docupath']
          .toString()
          .replaceAll('\\', '/')
          .split('/')
          .last;
    }

    final docPath = normalized['docupath']?.toString().trim();
    final docFilename = normalized['filename']?.toString().trim();
    if (docPath != null &&
        docPath.isNotEmpty &&
        docFilename != null &&
        docFilename.isNotEmpty) {
      final normalizedPath = docPath.replaceAll('\\', '/');
      final pathParts =
          normalizedPath.split('/').where((part) => part.isNotEmpty).toList();
      final basename = pathParts.isEmpty ? '' : pathParts.last;
      if (basename == 'Dokus' || !basename.contains('.')) {
        normalized['docupath'] = '$normalizedPath/$docFilename';
      }
    }

    return _$DocumentDataFromJson(normalized);
  }
  Map<String, dynamic> toJson() => _$DocumentDataToJson(this);
}
