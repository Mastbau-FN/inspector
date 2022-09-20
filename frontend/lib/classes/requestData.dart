import 'package:json_annotation/json_annotation.dart';
import 'package:image_picker/image_picker.dart';

part 'requestData.g.dart';

/// wraps all the data required for an api request
/// for simpler reuse
/// this gets stored if a request fails (in offline mode)
/// and retried when the app is online
@JsonSerializable()
class RequestData {
  RequestData(
    this.route, {
    this.json,
    this.multipartFiles = const [],
    this.timeout,
    this.returnsBinary = false,
    this.logIfFailed,
  });

  /// the route to the api
  String route;

  /// the json data to send
  Map<String, dynamic>? json;

  /// the files to send
  @JsonKey(toJson: _multipartFilesToJson, fromJson: _multipartFilesFromJson)
  List<XFile> multipartFiles;

  /// the timeout for the request
  Duration? timeout;

  /// if the request should return binary data
  bool returnsBinary;

  /// if the request should log if it failed, null to fallback to default behaviour (log everything that doesnt simulate a Get-Request)
  @JsonKey(ignore: true)
  bool? logIfFailed;

  Map<String, dynamic> get serialized => _$RequestDataToJson(this);
  static RequestData deserialize(Map<String, dynamic> json) =>
      _$RequestDataFromJson(json);
}

List<String> _multipartFilesToJson(List<XFile> files) => files
    .map((file) =>
        file.path) //XXX: path usage is discouraged as it wont work in web
    .toList();

List<XFile> _multipartFilesFromJson(List<dynamic> files) => files
    .map((file) => XFile(file
        .toString())) //XXX: path usage is discouraged as it wont work in web
    .toList();
