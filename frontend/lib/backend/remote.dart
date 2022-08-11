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
import 'package:MBG_Inspektionen/options.dart';

import './helpers.dart' as Helper;
import 'api.dart';

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
  RequestAndParser<http.BaseResponse, ImageData?> getImageByHash(String hash) {
    final rd = RequestData(
      _getImageFromHash_r,
      json: {
        'imghash': hash,
      },
      returnsBinary: true,
    );

    parser(http.BaseResponse _res) async {
      final res = _res.forceRes();
      if (res == null || res.statusCode != 200)
        return null;
      else {
        try {
          await API().local.storeImage(res.bodyBytes, hash);
          return ImageData(
            (await API().local.readImage(hash))!,
            id: hash,
          );
        } catch (e) {
          debugPrint("failed to load webimg: " + e.toString());
        }
      }
    }

    return RequestAndParser(rd: rd, parser: parser);
  }

  Future<DataT?> Function(Map<String, dynamic>)
      _generateImageFetcher<DataT extends Data>(
    DataT? Function(Map<String, dynamic>) jsoner,
  ) {
    // only fetch first image automagically and the others only when said so (or at least not make the UI wait for it (#34, #35))
    return (Map<String, dynamic> json) async {
      DataT? data = jsoner(json);
      if (data == null) return null;
      return injectImages(data);
    };
  }

  // Future<String> get rootID async => _user!.name;

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
  RequestAndParser<http.Response, http.Response?>
      _sendDataToRoute<DataT extends Data>({
    required DataT? data,
    required String route,
    Map<String, dynamic> other = const {},
  }) {
    if (Options().debugAllResponses)
      debugPrint("we will send this data to ${route}:" +
          (data?.toJson().toString() ?? ""));
    assert(data != null, 'we cant send no data, data needs to be supplied');
    var jsonData = data!.toJson();
    final rd = RequestData(route, json: {
      'type': Helper.getIdentifierFromData(data),
      'data': jsonData,
      ...other
    });

    parser(http.Response? res) {
      res = res?.forceRes();
      if (Options().debugAllResponses)
        debugPrint("and we received :" + (res?.body.toString() ?? ""));

      if (res?.statusCode != 200) {
        _maybeShowToast(
            "${S.current.anUnknownErrorOccured}, ${res?.statusCode}: ${res?.reasonPhrase}");
      }
      return res;
    }

    return RequestAndParser(rd: rd, parser: parser);
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
  RequestAndParser<http.Response, DataT?> setNew<DataT extends Data>(
    DataT? data,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _addNew_r,
      // networkIsCrucial: requestType != Helper.SimulatedRequestType.GET,
    );

    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body != null ? data : null;
        });
  }

  /// updates a [DataT] and returns the response
  RequestAndParser<http.Response, String?> update<DataT extends Data>(
    DataT? data,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _update_r,
    );

    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body;
        });
  }

  /// deletes a [DataT] and returns the response
  RequestAndParser<http.Response, String?> delete<DataT extends Data>(
    DataT? data,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _delete_r,
    );

    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body;
        });
  }

  /// deletes an image specified by its hash and returns the response
  RequestAndParser<http.BaseResponse, String?> deleteImageByHash(String hash) {
    final rd = RequestData(
      _deleteImageByHash_r,
      json: {'hash': hash},
    );

    parser(http.BaseResponse? res) => res?.forceRes()?.body;

    return RequestAndParser(rd: rd, parser: parser);
  }

  /// sets an image specified by its hash as the new main image
  RequestAndParser<http.Response, String?>
      setMainImageByHash<DataT extends Data>(
    DataT? data,
    String hash,
  ) {
    final rap = _sendDataToRoute(
      data: data,
      route: _setMainImageByHash_r,
      other: {
        'hash': hash,
      },
    );
    return RequestAndParser(
        rd: rap.rd,
        parser: (x) async {
          return (await rap.parser(x))?.body;
        });
  }

  /// upload a bunch of images
  RequestAndParser<http.BaseResponse, String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) {
    debugPrint('uploading images ${files}');
    var jsonData = data.toJson();
    final rd = RequestData(
      _uploadImage_r,
      json: {
        'type': Helper.getIdentifierFromData(data),
        'data': json.encode(jsonData),
      },
      multipart_files: files,
    );

    parser(http.BaseResponse res) async {
      if (res.statusCode != 200) {
        debugPrint('image uploading not ok: ${res.statusCode.toString()}');
        throw BackendCommunicationException(
            'we need a 200, but got ${res.statusCode}');
      }
      return (res.runtimeType == http.Response)
          ? (res as http.Response?)?.body //TODO meh remove crash und stuff
          : await (res as http.StreamedResponse?)?.stream.bytesToString();
    }

    return RequestAndParser(rd: rd, parser: parser);
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
