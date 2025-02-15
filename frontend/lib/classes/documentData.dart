import 'package:json_annotation/json_annotation.dart';
part 'documentData.g.dart';

@JsonSerializable()
class DocumentData {
  final String filename;
  final String docupath; // Base64

  DocumentData({required this.filename, required this.docupath});

  factory DocumentData.fromJson(Map<String, dynamic> json) =>
      _$DocumentDataFromJson(json);
  Map<String, dynamic> toJson() => _$DocumentDataToJson(this);
}
