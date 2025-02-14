import 'package:json_annotation/json_annotation.dart';
part 'documentData.g.dart';

@JsonSerializable()
class DocumentData {
  final String name;
  final String content; // Base64

  DocumentData({required this.name, required this.content});

  factory DocumentData.fromJson(Map<String, dynamic> json) =>
      _$DocumentDataFromJson(json);
  Map<String, dynamic> toJson() => _$DocumentDataToJson(this);
}
