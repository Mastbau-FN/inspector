// TODO offline storage etc, error handling

// BUG: FormatException

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/assets/consts.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';
import '/extension/future.dart';

const _debugAllResponses = true;

const _getProjects_r = '/projects/get';
const _getCategories_r = '/categories/get';
const _getCheckPoints_r = '/checkPoints/get';
const _getCheckPointDefects_r = '/checkPointDefects/get';

const _getImageFromHash_r = '/image/get';
const _uploadImage_r = "/image/set";

const _addNew_r = "/set";
const _update_r = "/update";
const _delete_r = "/delete"; // issue #36

const _deleteImageByHash_r = "/deleteImgH"; // issue #39
const _setMainImageByHash_r = "/setMainImgH"; // issue #20

extension _Parser on http.BaseResponse {
  http.Response? forceRes() {
    try {
      return this as http.Response;
    } catch (e) {
      return null;
    }
  }
}

/// backend Singleton to provide all functionality related to the backend
class Backend {
  // MARK: internals

  static final Backend _instance = Backend._internal();
  factory Backend() => _instance;

  Backend._internal() {
    // init
  }

  final _baseurl = dotenv.env['API_URL'];
  final _api_key = dotenv.env['API_KEY'] ?? "apitestkey";

  User? _user;

  /// returns the currently logged in [User], whether its already initialized or not.
  /// should be prefered over [_user], since it makes sure to have it initialized
  Future<User?> get _c_user async {
    if (_user != null) return _user;
    return await User.fromStore();
  }

  // MARK: available Helpers

  /// checks whether a connection to the backend is possible
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future connectionGuard() async {
    if (_baseurl == null)
      throw NoConnectionToBackendException("no url provided");

    //check network
    var connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException("no network available");
    if (!Consts.canUseMobileNetworkIfPossible &&
        connection == ConnectivityResult.mobile)
      throw NoConnectionToBackendException("mobile network not allowed");

    try {
      // check if we can reach our api
      await post_JSON('/login');
    } catch (e) {
      throw NoConnectionToBackendException("couldn't reach $_baseurl");
    }
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  Future<http.Response> post(
    String route, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    headers = headers ?? {};
    headers.addAll({HttpHeaders.authorizationHeader: _api_key});
    var fullURL = Uri.parse(_baseurl! + route);
    var ret = await http.post(
      fullURL,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    //if (_debugAllResponses) debugPrint(ret.statusCode.toString());//gibt momentan n 404, wird wohl zeit das backend zu deployen
    return ret;
  }

  /// post_JSON to our backend as the user
  Future<http.BaseResponse?> post_JSON(
    String route, {
    Map<String, dynamic>? json,
    List<XFile> multipart_files = const [],
  }) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    json = json ?? {};
    json['user'] = (await _c_user)?.toJson();
    try {
      if (multipart_files.isNotEmpty) {
        var fullURL = Uri.parse(_baseurl! + route);
        var mreq = http.MultipartRequest('POST', fullURL)
          ..files.addAll(
            List<http.MultipartFile>.from((await Future.wait(
              multipart_files.map(
                (xfile) async => await http.MultipartFile.fromPath(
                    'package', xfile.path,
                    filename: xfile.name),
              ),
            ))
                .whereType<http.MultipartFile>()),
          )
          ..headers.addAll({HttpHeaders.authorizationHeader: _api_key})
          ..fields.addAll(/*flatten()*/ json.map<String, String>(
              (key, value) => MapEntry(key, value.toString())));
        debugPrint("gonna send multipart-req with booty ${mreq.fields}");
        var res = await mreq.send();
        return res;
      }
      return post(route, headers: headers, body: jsonEncode(json));
    } catch (e) {
      debugPrint("request failed, cause : ${e}");
      return null;
    }
  }

  Future<ImageData?> _fetchImage(String hash) async {
    http.Response? res =
        (await post_JSON(_getImageFromHash_r, json: {'imghash': hash}))
            ?.forceRes();
    if (res == null || res.statusCode != 200) return null;
    return ImageData(Image.memory(res.bodyBytes),
        id: hash); //TODO ? jetzt werden den images durchgehend ihre hashes zugeordnet, aber reicht das? darüber müssen die bilder auf dem server erreicht werden können,(siehe zB #39). Kurzfristig hilft es wahrscheinlich die hashes langlebiger zu machen aber auf dauer muss da eine bessere Lösung her
  }

  Future<T?> Function(Map<String, dynamic>)
      _generateImageFetcher<T extends Data>(
    T? Function(Map<String, dynamic>) jsoner,
  ) {
    // only fetch first image automagically and the others only when said so (or at least not make the UI wait for it (#34, #35))
    return (Map<String, dynamic> json) async {
      //debugPrint(json.toString() + '\n');
      T? data = jsoner(json);
      if (data == null) return null;
      if (data.imagehashes == null ||
          data.imagehashes!.length == 0) //the second check *could* be omitted
        return data;

      int first_working_image_index = 0;
      data.mainImage =
          _fetchImage(data.imagehashes![first_working_image_index]);
      first_working_image_index++;

      //but we get another image anyway, since we want one that we can show as preview
      data.previewImage =
          IterateFuture.ordered_firstNonNull(data.imagehashes?.map(
                (hash) => _fetchImage(hash),
              ) ??
              []);
      //Future.doWhile(() => fetchdata)
      //Future.any(data.imagehashes?.map(
      //      (hash) => _fetchImage(hash),
      //    ) ??
      //    []);

      data.image_futures = data.imagehashes
          ?.map(
            (hash) => _fetchImage(hash),
          )
          .toList() /*.sublist(first_working_image_index + 1)*/;

      return data;
    };
  }

  /// Helper function to get the next [Data] (e.g. all [CheckPoint]s for chosen [CheckCategory])
  Future<List<D>> _getAllForNextLevel<D extends Data>({
    required String route,
    required String jsonResponseID,
    Map<String, dynamic>? json,
    required D? Function(Map<String, dynamic>) fromJson,
  }) async {
    Map<String, dynamic> _json = {};
    try {
      _json = jsonDecode(
        (await post_JSON(route, json: json))?.forceRes()?.body ?? '',
      );
    } catch (e) {
      debugPrint(e.toString());
    }
    return await getListFromJson(
      _json,
      _generateImageFetcher(fromJson),
      objName: jsonResponseID,
    );
  }

  /// since the backend api knows on which level we are by the identifier string, this function gets the identifiers for each kind of [DataT]
  /// it is very import to keep these in sinc with the actual backend
  String? _getIdentifierFromData<DataT extends Data>(DataT data) {
    switch (typeOf<DataT>()) {
      case CheckCategory:
        return 'category';

      case CheckPoint:
        return 'checkpoint';

      case CheckPointDefect:
        return 'defect';

      default:
        debugPrint("yo this type is not supported : ${typeOf<DataT>()}");
        return null;
    }
  }

  /// sends a [DataT] with the corresponding identifier to the given route
  Future<http.Response?> _sendDataToRoute<DataT extends Data>(
      {required DataT? data,
      required String route,
      Map<String, dynamic> other = const {}}) async {
    debugPrint(data?.toJson().toString());
    if (data == null) return null;
    var json_data = data.toJson();
    http.Response? res = (await post_JSON(route, json: {
      'type': _getIdentifierFromData(data),
      'data': json_data,
      ...other
    }))
        ?.forceRes();
    debugPrint(res?.body.toString());
    return res;
  }

  // MARK: API

  /// checks whether the given user is currently logged in
  Future<bool> isUserLoggedIn(User user) async => user == await _c_user;

  /// checks whether anyone is currently logged in
  Future<bool> get isAnyoneLoggedIn async => await _c_user != null;

  /// gets the currently logged in [DisplayUser], which is the current [User] but with removed [User.pass] to avoid abuse
  Future<DisplayUser?> get user async => await _c_user;

  /// login a [User] by checking if he exists in the remote database
  Future<DisplayUser?> login(User user) async {
    // if user is already logged in
    if (await isUserLoggedIn(user)) return await this.user;
    await connectionGuard();
    _user = user;
    var res = (await post_JSON('/login'))?.forceRes();
    if (res != null && res.statusCode == 200) {
      //success
      var resb = jsonDecode(res.body)['user'];
      _user?.fromMap(resb);
      await _user?.store();
      return this.user;
    }
    await logout(); //we could omit the await for a slight speed improvement (but if anything crashes for some reason it could lead to unexpected behaviour)
    throw ResponseException(res);
  }

  /// removes the credentials from local storage and therefors logs out
  Future logout() async {
    (await _c_user)?.unstore();
    _user = null;
    debugPrint('user logged out');
  }

  /// gets all the [InspectionLocation]s for the currently logged in [user]
  Future<List<InspectionLocation>> getAllInspectionLocationsForCurrentUser() =>
      _getAllForNextLevel(
        route: _getProjects_r,
        jsonResponseID: 'inspections',
        fromJson: InspectionLocation.fromJson,
      );

  /// gets all the [CheckCategory]s for the given [InspectionLocation]
  Future<List<CheckCategory>> getAllCheckCategoriesForLocation(
          InspectionLocation location) =>
      _getAllForNextLevel(
        route: _getCategories_r,
        jsonResponseID: 'categories',
        json: location.toSmallJson(),
        fromJson: CheckCategory.fromJson,
      );

  /// gets all the [CheckPoint]s corresponding to a given [CheckCategory]
  Future<List<CheckPoint>> getAllCheckPointsForCategory(
          CheckCategory category) =>
      _getAllForNextLevel(
        route: _getCheckPoints_r,
        jsonResponseID: 'checkpoints',
        json: category.toSmallJson(),
        fromJson: CheckPoint.fromJson,
      );

  /// gets all the [CheckPointDefect]s for the given [CheckPoint]
  Future<List<CheckPointDefect>> getAllDefectsForCheckpoint(
          CheckPoint checkpoint) =>
      _getAllForNextLevel(
        route: _getCheckPointDefects_r,
        jsonResponseID: 'checkpointdefects',
        json: checkpoint.toSmallJson(),
        fromJson: CheckPointDefect.fromJson,
      );

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(DataT? data) async {
    var body = (await _sendDataToRoute(data: data, route: _addNew_r))?.body;
    //XXX if the resulting Data is needed we would need to pass it correctly from this response body, the following just returns the input on success
    return body == null ? null : data;
  }

  /// updates a [DataT] and returns the response
  Future<String?> update<DataT extends Data>(DataT? data) async =>
      (await _sendDataToRoute(data: data, route: _update_r))?.body;

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(DataT? data) async =>
      (await _sendDataToRoute(data: data, route: _delete_r))?.body;

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async =>
      (await post_JSON(_deleteImageByHash_r, json: {'hash': hash}))
          ?.forceRes()
          ?.body;

  /// sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
          DataT? data, String hash) async =>
      (await _sendDataToRoute(
        data: data,
        route: _setMainImageByHash_r,
        other: {
          'hash': hash,
        },
      ))
          ?.body;

  /// upload a bunch of images
  Future<String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) async {
    ////ODO: we currently store everything n the root dir, but we want to add into specific subdir that needs to be extracted from rew.body.E1 etc
    debugPrint('uploading images ${files}');
    var res = await post_JSON(
      _uploadImage_r,
      json: data.toJson(),
      multipart_files: files,
    ); //wont work
    if (res?.statusCode != 200) {
      debugPrint(res?.statusCode.toString());
      debugPrint(res?.contentLength.toString());
    }
    return (res.runtimeType == http.Response)
        ? (res as http.Response?)?.body //TODO meh remove crash und stuff
        : await (res as http.StreamedResponse?)?.stream.bytesToString();
  }
}

/// Helper function to parse a [List] of [Data] Objects from a Json-[Map]
Future<List<T>> getListFromJson<T extends Data>(Map<String, dynamic> json,
    FutureOr<T?> Function(Map<String, dynamic>) converter,
    {String? objName}) async {
  try {
    List<dynamic> str = (objName != null) ? json[objName] : json;
    return List<T>.from(
        (await Future.wait(str.map((elem) async => await converter(elem))))
            .whereType<T>());
  } catch (e) {
    debugPrint(e.toString());
    throw BackendCommunicationException(
        'could not parse response: ' + e.toString());
  }
  //return [];
}
