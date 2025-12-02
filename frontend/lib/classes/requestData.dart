import 'dart:convert';

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
    final scope = _deriveScopeFromJson(json);
    String scoped(String base) =>
        scope != null && scope.isNotEmpty ? '$scope/$base' : base;

    this.multipartFileNames ??= await Future.wait(
        _multipartFiles! //either names or files are set
            .map((file) async => await OP.permaStoreCachedXFile(
                file, scoped(LOCALLY_ADDED_PREFIX + file.name))));
    return _$RequestDataToJson(this);
  }

  static RequestData deserialize(Map<String, dynamic> json) {
    var rd = _$RequestDataFromJson(json);
    rd.multipartFileNames = rd.multipartFileNames?.map((element) {
      // fix for failed uploads in pratiks latest incident (02)
      if (element.contains(LOCALLY_ADDED_PREFIX) &&
          !element.contains('/')) {
        //shouldnt be necessary but just in case, but keep folder paths intact
        element = element.substring(element.indexOf(LOCALLY_ADDED_PREFIX));
      }
      return element;
    }).toList();
    return rd;
  }
}

String? _deriveScopeFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  dynamic dataField = json['data'];
  Map<String, dynamic>? data;
  if (dataField is String) {
    try {
      data = jsonDecode(dataField) as Map<String, dynamic>?;
    } catch (_) {}
  } else if (dataField is Map<String, dynamic>) {
    data = dataField;
  }
  if (data == null) return null;

  final parentId = data['parent_local_id']?.toString();
  if (parentId != null && parentId.isNotEmpty) return parentId;

  final type = json['type']?.toString();
  final pj = data['PjNr']?.toString();
  if (pj == null || pj.isEmpty) return null;

  String seg2 = 'undefined';
  String seg3 = 'undefined';
  String seg4 = 'undefined';

  switch (type) {
    case 'defect':
      seg2 = data['E1']?.toString() ?? seg2;
      seg3 = data['E2']?.toString() ?? seg3;
      seg4 = data['E3']?.toString() ?? seg4;
      break;
    case 'checkpoint':
      seg2 = data['E1']?.toString() ?? seg2;
      seg3 = data['E2']?.toString() ?? seg3;
      seg4 = data['E3']?.toString() ?? seg4;
      break;
    case 'location':
      // only pjNr needed
      break;
    default:
      break;
  }

  return [pj, seg2, seg3, seg4].join('-');
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
