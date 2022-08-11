import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart' show RequestData;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import '../generated/l10n.dart';
import '../helpers/toast.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';
import '/extension/future.dart';
import 'package:MBG_Inspektionen/options.dart';

import './offlineProvider.dart' as OP;
import './helpers.dart' as Helper;

String routesFromData<DataT extends Data>(DataT? data) =>
    '/${Helper.getIdentifierFromData(data)}/get';

const _getImageFromHash_r = '/image/get';
const _uploadImage_r = "/image/set";

const _addNew_r = "/set";
const _update_r = "/update";
const _delete_r = "/delete"; // issue #36

const _deleteImageByHash_r = "/deleteImgH"; // issue #39
const _setMainImageByHash_r = "/setMainImgH"; // issue #20

class RequestAndParser<Response extends http.BaseResponse, T> {
  final RequestData rd;
  final FutureOr<T> Function(Response) parser;

  RequestAndParser({required this.rd, required this.parser});
}

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
class Remote {
  // MARK: internals

  static final Remote _instance = Remote._internal();
  factory Remote() => _instance;

  Remote._internal() {
    // init
  }

  User? _user;
  injectUser(User? user) => _user = user;

  final _baseurl = dotenv.env['API_URL'];
  final _api_key = dotenv.env['API_KEY'] ?? "apitestkey";

  // MARK: available Helpers

  /// checks whether a connection to the backend is possible
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future connectionGuard({Duration? timeout}) async {
    if (_baseurl == null)
      throw NoConnectionToBackendException(
          S.current.exceptionNoUrlToConnectToProvided);
    try {
      // check if we can reach our api
      await post_JSON(RequestData(
        '/login',
        timeout: timeout,
      )); ////logIfFailed: false));
    } catch (e) {
      throw NoConnectionToBackendException(
          S.current.couldntReach + " $_baseurl");
    }
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  Future<http.Response?> post(
    String route, {
    Map<String, String>? headers,
    String? body,
    Encoding? encoding,
    Duration? timeout,
  }) =>
      send(
        makepost(route, headers: headers, body: body, encoding: encoding),
        timeout: timeout,
      );

  Future<http.Response?> send(
    http.Request request, {
    Duration? timeout,
    bool returnsBinary = false,
  }) async {
    final req = request.send();
    final res = (timeout == null) ? await req : await req.timeout(timeout);

    final ret = await http.Response.fromStream(res); // res.forceRes();
    if (Options().debugAllResponses && !returnsBinary)
      debugPrint("res: " + ret.body);
    return ret;
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  http.Request makepost(
    String route, {
    Map<String, String>? headers,
    String? body,
    Encoding? encoding,
  }) {
    headers = headers ?? {};
    headers.addAll({HttpHeaders.authorizationHeader: _api_key});
    var fullURL = Uri.parse(_baseurl! + route);
    final req = http.Request('post', fullURL)..headers.addAll(headers);
    if (encoding != null) req.encoding = encoding;
    if (body != null) req.body = body;
    return req;
  }

  /// post_JSON to our backend as the user
  Future<http.BaseResponse?> post_JSON(RequestData rd) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    rd.json = rd.json ?? {};
    rd.json!['user'] = _user?.toJson();
    if (Options().debugAllResponses) debugPrint('req: ' + jsonEncode(json));
    try {
      if (rd.multipart_files.isNotEmpty) {
        http.MultipartRequest? mreq;
        try {
          var fullURL = Uri.parse(_baseurl! + rd.route);
          mreq = http.MultipartRequest('POST', fullURL)
            ..files.addAll(
              List<http.MultipartFile>.from((await Future.wait(
                rd.multipart_files.map(
                  (xfile) => http.MultipartFile.fromPath('package', xfile.path,
                      filename: xfile.name),
                ),
              ))
                  .whereType<http.MultipartFile>()),
            )
            ..headers.addAll({HttpHeaders.authorizationHeader: _api_key})
            ..fields.addAll(/*flatten()*/ rd.json!.map<String, String>(
                (key, value) => MapEntry(key, value.toString())));
          debugPrint("gonna send multipart-req with booty ${mreq.fields}");
          var res = (rd.timeout == null)
              ? await mreq.send()
              : await mreq.send().timeout(rd.timeout!);
          return res;
        } on Exception catch (e) {
          //if (rd.////logIfFailed) OP.logFailedReq(rd);
          debugPrint('multipartRequest, failed');
          throw e;
        }
      } else {
        final req =
            makepost(rd.route, headers: headers, body: jsonEncode(rd.json));
        try {
          return await send(
            req,
            timeout: rd.timeout,
            returnsBinary: rd.returnsBinary,
          );
        } catch (e) {
          //if (rd.////logIfFailed) OP.logFailedReq(rd);
          debugPrint('request failed');
          throw e;
        }
      }
    } catch (e) {
      debugPrint("request failed, cause : ${e}");
      return null;
    }
  }

  //final _imageStreamController = BehaviorSubject<String>();
  Stream<ImageData?> _fetchImage(String hash) async* {
    bool cacheHit = false;
    if (Options().canBeOffline)
      try {
        final img = await OP.readImage(hash);
        if (img == null) throw Exception("no img cached");
        yield ImageData(img, id: hash);
        cacheHit = true;
      } catch (e) {
        //yield null;
      }
    if (!cacheHit || Options().preferRemote) {
      http.Response? res = (await post_JSON(RequestData(
        _getImageFromHash_r,
        json: {
          'imghash': hash,
        },
        returnsBinary: true,
        ////logIfFailed: false,
      )))
          ?.forceRes();
      if (res == null || res.statusCode != 200)
        yield null;
      else {
        try {
          await OP.storeImage(res.bodyBytes, hash);
          yield ImageData(
            (await OP.readImage(hash))!,
            id: hash,
          );
        } catch (e) {
          debugPrint("failed to load webimg: " + e.toString());
        }
      }
    }
  }

  //final _imageStreamController = BehaviorSubject<String>();
  Future<ImageData?> _fetchImage_fut(String hash) async {
    bool cacheHit = false;
    if (Options().canBeOffline && !Options().preferRemote) {
      try {
        final img = await OP.readImage(hash);
        if (img == null) throw Exception("no img cached");
        cacheHit = true;
        return ImageData(img, id: hash);
      } catch (e) {
        //yield null;
      }
    }
    if (!cacheHit || Options().preferRemote) {
      http.Response? res = (await post_JSON(RequestData(
        _getImageFromHash_r,
        json: {
          'imghash': hash,
        },
        returnsBinary: true,
        ////logIfFailed: false,
      )))
          ?.forceRes();
      if (res == null || res.statusCode != 200)
        return null;
      else {
        try {
          await OP.storeImage(res.bodyBytes, hash);
          return ImageData(
            (await OP.readImage(hash))!,
            id: hash,
          );
        } catch (e) {
          debugPrint("failed to load webimg: " + e.toString());
        }
      }
    }
  }

  Future<DataT?> Function(Map<String, dynamic>)
      _generateImageFetcher<DataT extends Data>(
    DataT? Function(Map<String, dynamic>) jsoner,
  ) {
    // only fetch first image automagically and the others only when said so (or at least not make the UI wait for it (#34, #35))
    return (Map<String, dynamic> json) async {
      DataT? data = jsoner(json);
      if (data == null) return null;
      if (data.imagehashes == null ||
          data.imagehashes!.length == 0) //the second check *could* be omitted
        return data;

      int first_working_image_index = 0;
      String __hash = data.imagehashes![first_working_image_index];
      data.mainImage = (__hash == Options().no_image_placeholder_name)
          ? null
          : _fetchImage_fut(__hash);
      first_working_image_index++;

      //but we get another image anyway, since we want one that we can show as preview
      data.previewImage = IterateFuture.ordered_firstNonNull(data.imagehashes?.map(
              (hash) => _fetchImage_fut(hash)
              //.asBroadcastStream()
              // .repeatLatest(), //XXX: we dont want them to be broadcasts but it seems to crash on statechange otherwise
              ) ??
          []);
      //Future.doWhile(() => fetchdata)
      //Future.any(data.imagehashes?.map(
      //      (hash) => _fetchImage(hash),
      //    ) ??
      //    []);

      if (Options().debugImages)
        debugPrint("image-hashes: " + data.imagehashes.toString());

      data.image_futures = data.imagehashes
          ?.map((hash) => _fetchImage_fut(hash)
              // .asBroadcastStream()
              // .repeatLatest(), //XXX: we dont want them to be broadcasts but it seems to crash on statechange otherwise
              )
          .toList()
          .sublist((__hash == Options().no_image_placeholder_name) ? 1 : 0);

      return data;
    };
  }

  Future<String> get rootID async => _user!.name;

  /// Helper function to get the next [Data] (e.g. all [CheckPoint]s for chosen [CheckCategory])
  RequestAndParser<http.Response, List<ChildData>>
      _getAllForNextLevel<ChildData extends Data, ParentData extends Data>({
    required String route,
    required String jsonResponseID,
    Map<String, dynamic>? json,
    required ChildData? Function(Map<String, dynamic>) fromJson,
  }) {
    final rd = RequestData(
      route,
      json: json,
      timeout: Duration(seconds: 10),
      ////logIfFailed: false,
    );

    Future<List<ChildData>> parser(http.Response? res) {
      Future<ChildData?> Function(Map<String, dynamic>) imageFetcher =
          _generateImageFetcher(fromJson);
      Future<List<ChildData>> __parse(__json) => getListFromJson(
            __json,
            imageFetcher,
            objName: jsonResponseID,
          );
      final body = res!.forceRes()!.body;
      final _json = jsonDecode(body);
      return __parse(_json);
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  /// sends a [DataT] with the corresponding identifier to the given route
  Future<http.Response?> _sendDataToRoute<DataT extends Data>(
      {required DataT? data,
      required String route,
      Map<String, dynamic> other = const {},
      bool networkIsCrucial = false}) async {
    if (networkIsCrucial || !Options().canBeOffline)
      try {
        await connectionGuard();
      } catch (error) {
        showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
        return null;
      }

    if (Options().debugAllResponses)
      debugPrint(
          "we send this data to ${route}:" + (data?.toJson().toString() ?? ""));
    if (data == null) return null;
    var json_data = data.toJson();
    final reqData = RequestData(route, json: {
      'type': Helper.getIdentifierFromData(data),
      'data': json_data,
      ...other
    });
    try {
      await connectionGuard();
    } catch (e) {
      OP.logFailedReq(reqData);
      return null;
    }
    http.Response? res = (await post_JSON(reqData))?.forceRes();
    if (Options().debugAllResponses)
      debugPrint("and we received :" + (res?.body.toString() ?? ""));

    if (res?.statusCode != 200) {
      _maybeShowToast(
          "${S.current.anUnknownErrorOccured}, ${res?.statusCode}: ${res?.reasonPhrase}");
    }
    return res;
  }

  void _maybeShowToast(String? message) {
    if (message != null && message != "") {
      showToast(message);
    }
  }

  // MARK: API

  /// login a [User] by checking if he exists in the remote database
  Future<User?> login(User user) async {
    // if user is already logged in
    await connectionGuard();
    _user = user;
    var res = (await post_JSON(RequestData(
      '/login',
    ))) ////logIfFailed: false)))
        ?.forceRes();
    if (res != null && res.statusCode == 200) {
      //success
      var resb = jsonDecode(res.body)['user'];
      _user?.fromMap(resb);
      return _user;
    }
    throw ResponseException(res);
  }

  /// gets all the [ChildData]points for the given [ParentData]
  /// if no [ParentData] is given it defaults to root
  RequestAndParser<http.Response, List<ChildData>>
      getNextDatapoint<ChildData extends Data, ParentData extends WithOffline?>(
    ParentData data,
  ) {
    final childTypeStr = Helper.getIdentifierFromData<ChildData>(null);
    if (childTypeStr == null) throw Exception('type not supported');
    return _getAllForNextLevel(
        route: routesFromData<ChildData>(null),
        jsonResponseID: childTypeStr + 's',
        json: data?.toSmallJson(),
        fromJson: (json) => /*Child*/ Data.fromJson<ChildData>(json));
  }

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    var body = (await _sendDataToRoute(
      data: data,
      route: _addNew_r,
      // networkIsCrucial: requestType != Helper.SimulatedRequestType.GET,
    ))
        ?.body;
    //XXX if the resulting Data is needed we would need to pass it correctly from this response body, the following just returns the input on success
    return body == null ? null : data;
  }

  /// updates a [DataT] and returns the response
  Future<String?> update<DataT extends Data>(
    DataT? data, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    return (await _sendDataToRoute(
      data: data,
      route: _update_r,
    ))
        ?.body;
  }

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    return (await _sendDataToRoute(
      data: data,
      route: _delete_r,
    ))
        ?.body;
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async {
    return (await post_JSON(RequestData(
      _deleteImageByHash_r,
      json: {'hash': hash},
      ////logIfFailed: true,
    )))
        ?.forceRes()
        ?.body;
  }

  /// sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    return (await _sendDataToRoute(
      data: data,
      route: _setMainImageByHash_r,
      other: {
        'hash': hash,
      },
      // networkIsCrucial: requestType != Helper.SimulatedRequestType.GET,
    ))
        ?.body;
  }

  /// upload a bunch of images
  Future<String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
    ////ODO: we currently store everything n the root dir, but we want to add into specific subdir that needs to be extracted from rew.body.E1 etc

    //TODO: #211 add offline procedure
    debugPrint('uploading images ${files}');
    var json_data = data.toJson();
    final reqData = RequestData(
      _uploadImage_r,
      json: {
        'type': Helper.getIdentifierFromData(data),
        'data': json.encode(json_data),
      },
      multipart_files: files,
      ////logIfFailed: requestType != Helper.SimulatedRequestType.GET,
    );
    try {
      await connectionGuard();
      var res = await post_JSON(reqData);
      if (res?.statusCode != 200) {
        debugPrint('not ok: ${res?.statusCode.toString()}');
        // debugPrint(res?.contentLength.toString());
      }
      return (res.runtimeType == http.Response)
          ? (res as http.Response?)?.body //TODO meh remove crash und stuff
          : await (res as http.StreamedResponse?)?.stream.bytesToString();
    } catch (e) {
      OP.logFailedReq(reqData);
    }
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
    debugPrint(
        'could not parse response: ' + e.toString() + '<--' + jsonEncode(json));
    throw BackendCommunicationException(
        S.current.couldNotParseResponse + jsonEncode(json));
  }
  //return [];
}
