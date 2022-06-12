import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/assets/consts.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:tuple/tuple.dart';
import '../generated/l10n.dart';
import '../helpers/toast.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';
import '/extension/future.dart';

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
  Future connectionGuard({
    Duration? timeout,
  }) async {
    if (_baseurl == null)
      throw NoConnectionToBackendException(
          S.current.exceptionNoUrlToConnectToProvided);

    //check network
    var connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException(S.current.noNetworkAvailable);
    if (!Options.canUseMobileNetworkIfPossible &&
        connection == ConnectivityResult.mobile)
      throw NoConnectionToBackendException(S.current.mobileNetworkNotAllowed);

    try {
      // check if we can reach our api
      await post_JSON('/login', timeout: timeout);
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
    if (Options.debugAllResponses && !returnsBinary)
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
  Future<http.BaseResponse?> post_JSON(
    String route, {
    Map<String, dynamic>? json,
    List<XFile> multipart_files = const [],
    Duration? timeout,
    bool returnsBinary = false,
  }) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    json = json ?? {};
    json['user'] = (await _c_user)?.toJson();
    if (Options.debugAllResponses) debugPrint('req: ' + jsonEncode(json));
    try {
      if (multipart_files.isNotEmpty) {
        http.MultipartRequest? mreq;
        try {
          var fullURL = Uri.parse(_baseurl! + route);
          mreq = http.MultipartRequest('POST', fullURL)
            ..files.addAll(
              List<http.MultipartFile>.from((await Future.wait(
                multipart_files.map(
                  (xfile) => http.MultipartFile.fromPath('package', xfile.path,
                      filename: xfile.name),
                ),
              ))
                  .whereType<http.MultipartFile>()),
            )
            ..headers.addAll({HttpHeaders.authorizationHeader: _api_key})
            ..fields.addAll(/*flatten()*/ json.map<String, String>(
                (key, value) => MapEntry(key, value.toString())));
          debugPrint("gonna send multipart-req with booty ${mreq.fields}");
          var res = (timeout == null)
              ? await mreq.send()
              : await mreq.send().timeout(timeout);
          return res;
        } on Exception catch (e) {
          OP.logFailedReq(mreq!);
          debugPrint('multipartRequest, failed, we logged it');
          throw e;
        }
      } else {
        final req = makepost(route, headers: headers, body: jsonEncode(json));
        try {
          return await send(
            req,
            timeout: timeout,
            returnsBinary: returnsBinary,
          );
        } catch (e) {
          OP.logFailedReq(req);
          debugPrint('request, failed, we logged it');
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
    try {
      final img = await OP.readImage(hash);
      if (img == null) throw Exception("no img cached");
      yield ImageData(img, id: hash);
      cacheHit = true;
    } catch (e) {
      //yield null;
    }
    if (!cacheHit || Options.preferRemoteImages) {
      http.Response? res = (await post_JSON(
        _getImageFromHash_r,
        json: {
          'imghash': hash,
        },
        returnsBinary: true,
      ))
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
    if (!Options.preferRemoteImages) {
      try {
        final img = await OP.readImage(hash);
        if (img == null) throw Exception("no img cached");
        return ImageData(img, id: hash);
        cacheHit = true;
      } catch (e) {
        //yield null;
      }
    } else {
      http.Response? res = (await post_JSON(
        _getImageFromHash_r,
        json: {
          'imghash': hash,
        },
        returnsBinary: true,
      ))
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
      data.mainImage = (__hash == Options.no_image_placeholder_name)
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

      if (Options.debugImages)
        debugPrint("image-hashes: " + data.imagehashes.toString());

      data.image_futures = data.imagehashes
          ?.map((hash) => _fetchImage_fut(hash)
              // .asBroadcastStream()
              // .repeatLatest(), //XXX: we dont want them to be broadcasts but it seems to crash on statechange otherwise
              )
          .toList()
          .sublist((__hash == Options.no_image_placeholder_name) ? 1 : 0);

      return data;
    };
  }

  /// Helper function to get the next [Data] (e.g. all [CheckPoint]s for chosen [CheckCategory])
  Stream<List<ChildData>>
      _getAllForNextLevel<ChildData extends Data, ParentData extends Data>({
    required String route,
    required String jsonResponseID,
    Map<String, dynamic>? json,
    required ChildData? Function(Map<String, dynamic>) fromJson,
    String? id,
  }) async* {
    // yield [];
    assert(
        (await user) != null, S.current.wontFetchAnythingSinceNoOneIsLoggedIn);
    String _id = id ?? json?['local_id'] ?? (await user)!.name;
    Map<String, dynamic> _json = {};
    Future<ChildData?> Function(Map<String, dynamic>) imageFetcher =
        _generateImageFetcher(fromJson);

    Future<List<ChildData>> __parse(__json) => getListFromJson(
          __json,
          imageFetcher,
          // _generateImageFetcher(fromJson),
          objName: jsonResponseID,
        );
    if (Options.canBeOffline)
      try {
        _json = jsonDecode("{\"$jsonResponseID\": ${jsonEncode(
            // Ähhh ja die liste muss wie die response aussehen damit die function weiter unten die images fetchet
            (await OP.getAllChildrenFrom<ChildData>(_id)))}}");
        yield await __parse(_json);
      } catch (e) {
        debugPrint("couldnt read data from disk..: " + e.toString());
      }

    try {
      final res = (await post_JSON(
        route,
        json: json,
        timeout: Duration(seconds: 10),
      ));
      final body = res!.forceRes()!.body;
      _json = jsonDecode(body);
      var datapoints = await __parse(_json);
      yield datapoints;
      for (var data in datapoints) {
        String childId = await OP.storeData(data, forId: _id);
        if (Options.debugLocalMirror)
          debugPrint("stored new child with id: " + childId);
      }
    } catch (e) {
      debugPrint("couldnt reach API: " + e.toString());
    }

    if (Options.debugAllResponses)
      debugPrint("_getAllForNextLevel received: " + jsonEncode(json));
  }

  /// sends a [DataT] with the corresponding identifier to the given route
  Future<http.Response?> _sendDataToRoute<DataT extends Data>(
      {required DataT? data,
      required String route,
      Map<String, dynamic> other = const {},
      bool networkIsCrucial = false}) async {
    if (networkIsCrucial || !Options.canBeOffline)
      try {
        await connectionGuard();
      } catch (error) {
        showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
        return null;
      }

    if (Options.debugAllResponses)
      debugPrint(
          "we send this data to ${route}:" + (data?.toJson().toString() ?? ""));
    if (data == null) return null;
    var json_data = data.toJson();
    http.Response? res = (await post_JSON(route, json: {
      'type': Helper.getIdentifierFromData(data),
      'data': json_data,
      ...other
    }))
        ?.forceRes();
    if (Options.debugAllResponses)
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

  /// gets all the [ChildData]points for the given [ParentData]
  /// if no [ParentData] is given it defaults to root
  Stream<List<ChildData>>
      getNextDatapoint<ChildData extends Data, ParentData extends Data?>(
    ParentData data,
  ) async* {
    if (!Options.canBeOffline)
      try {
        await connectionGuard();
      } catch (error) {
        showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
        yield [];
      }
    final childTypeStr = Helper.getIdentifierFromData<ChildData>(null);
    if (childTypeStr == null) throw Exception('type not supported');
    await for (var l in _getAllForNextLevel(
      route: routesFromData<ChildData>(null),
      jsonResponseID: childTypeStr + 's',
      json: data?.toSmallJson(),
      fromJson: (json) => /*Child*/ Data.fromJson<ChildData>(json),
    )) {
      // debugPrint('new value $l');
      yield l;
    }
  }

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(DataT? data) async {
    var body = (await _sendDataToRoute(
            data: data, route: _addNew_r, networkIsCrucial: true))
        ?.body;
    //XXX if the resulting Data is needed we would need to pass it correctly from this response body, the following just returns the input on success
    return body == null ? null : data;
  }

  /// updates a [DataT] and returns the response
  Future<String?> update<DataT extends Data>(DataT? data) async =>
      (await _sendDataToRoute(
              data: data, route: _update_r, networkIsCrucial: true))
          ?.body;

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(DataT? data) async =>
      (await _sendDataToRoute(
              data: data, route: _delete_r, networkIsCrucial: true))
          ?.body;

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async {
    await OP.deleteImage(hash);
    return (await post_JSON(_deleteImageByHash_r, json: {'hash': hash}))
        ?.forceRes()
        ?.body;
  }

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
    var json_data = data.toJson();
    var res = await post_JSON(
      _uploadImage_r,
      json: {
        'type': Helper.getIdentifierFromData(data),
        'data': json.encode(json_data),
      },
      multipart_files: files,
    ); //wont work
    if (res?.statusCode != 200) {
      debugPrint('not ok: ${res?.statusCode.toString()}');
      // debugPrint(res?.contentLength.toString());
    }
    return (res.runtimeType == http.Response)
        ? (res as http.Response?)?.body //TODO meh remove crash und stuff
        : await (res as http.StreamedResponse?)?.stream.bytesToString();
  }

  /// removes all locally stored images via [OP]
  final deleteCache = OP.deleteAll;

  retryFailedrequests() async {
    for (Tuple2<String, Tuple2<http.Request?, http.MultipartRequest?>> reqd
        in await OP.getAllFailedRequests() ?? []) {
      final docID = reqd.item1;
      final _reqTuple = reqd.item2;
      try {
        final req = (_reqTuple.item1 ?? _reqTuple.item2)!;
        final res = http.Response.fromStream(await req.send());
        OP.failedRequestWasSuccesful(docID);
      } finally {}
    }
  }

  //TODO: so ganz scheint das noch nicht zu gehen, da iwie alles bei allem angezeigt wird, fehler könnte aber auch im OP liegen
  /// recursivle cache all elements that underly the caller
  Future<bool> loadAndCacheAll<
      ChildData extends WithLangText,
      ParentData extends Data,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
  }) async {
    debugPrint('loading ${depth}');
    //base-case: CheckPointDefects have no children
    // if (typeOf<ChildData>() == CheckPointDefect) return true;//XXX: shit, this generic bums wont work
    if (depth == 0) return true;
    depth--;
    try {
      //fail early if no connection
      await connectionGuard();
      //get all children, this will also cache them internally
      var children = await caller.all.last;
      var didSucceed = await Future.wait(children.map((child) {
        String _name = '$name -> ${child.title}';
        debugPrint('__1234 got $depth: $_name');
        if (depth == 0)
          return Future.value(
              true); //base-case as to not call generateNextModel
        return loadAndCacheAll(caller.generateNextModel(child), depth,
            name: _name);
      }));
      //if all children succeeded recursive calling succeeded
      return didSucceed.every((el) => el);
    } catch (error) {
      showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
      return false; //failed
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
