import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/backend/offlineProvider.dart' as OP;

part 'requestData.g.dart';

/// wraps all the data required for an api request
/// for simpler reuse
/// this gets stored if a request fails (in offline mode) it is therefor offline only
/// and retried when the app is online
@JsonSerializable()
class RequestData {
  RequestData(
    this.route, {
    this.json,
    this.multipartFileNames = const [],
    this.timeout,
    this.returnsBinary = false,
    this.logIfFailed,
  });

  RequestData.fromFiles(
    this.route, {
    this.json,
    List<XFile>? multipartFiles,
    this.timeout,
    this.returnsBinary = false,
    this.logIfFailed,
  }) : _multipartFiles = multipartFiles;

  /// the route to the api
  String route;

  /// the json data to send
  Map<String, dynamic>? json;

  /// the files to send
  // @JsonKey(
  //     toJson: multipartFilesToHashList, fromJson: multipartFilesFromHashList)
  @JsonKey(name: 'multipartFiles')
  List<String>? multipartFileNames;

  @JsonKey(includeFromJson: false, includeToJson: false)
  List<XFile>? _multipartFiles;
  @JsonKey(includeFromJson: false, includeToJson: false)
  List<Future<XFile>> get multipartFiles =>
      _multipartFiles?.map((e) => Future.value(e)).toList() ??
      multipartFileNames! //either names or files are set
          .map((filename) => OP.retrieveStoredXFile(filename))
          .toList();

  /// the timeout for the request
  Duration? timeout;

  /// if the request should return binary data
  bool returnsBinary;

  /// if the request should log if it failed, null to fallback to default behaviour (log everything that doesnt simulate a Get-Request)
  @JsonKey(includeToJson: false)
  bool? logIfFailed;

  /// only gets called when the request failed and has to be tried again later
  Future<Map<String, dynamic>> get serialized async {
    //when storing files we have to make sure they are permanently stored, not only in cache
    this.multipartFileNames ??= await Future.wait(
        _multipartFiles! //either names or files are set
            .map((file) async => await OP.permaStoreCachedXFile(
                file, LOCALLY_ADDED_PREFIX + file.name)));
    return _$RequestDataToJson(this);
  }

  static RequestData deserialize(Map<String, dynamic> json) {
    var rd = _$RequestDataFromJson(json);
    rd.multipartFileNames?.forEach((element) {
      // fix for failed uploads in pratiks latest incident (02)
      if (element.contains('cache/')) {
        //get only stuff behind 'cache/'
        element = element.substring(element.indexOf('cache/') + 6);
      }
    });
    return rd;
  }
}

// List<String> multipartFilesToHashList(List<XFile> files) => files
//     .map((file) =>
//         file.name) //XXX: path usage is discouraged as it wont work in web
//     .toList();

// List<XFile> multipartFilesFromHashList(List<dynamic> files) async =>
//     files
//         .map((filename) async => XFile(
//             (await API().local.getLocalFilePathFromName(filename))
//                 .path)) //XXX: path usage is discouraged as it wont work in web
//         .toList();
