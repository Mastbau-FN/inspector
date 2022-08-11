import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart' show RequestData;
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import '../generated/l10n.dart';
import '../helpers/toast.dart';
import '../pages/location.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';
import '/extension/future.dart';
import 'package:MBG_Inspektionen/options.dart';

import './offlineProvider.dart' as OP;
import './helpers.dart' as Helper;
import 'api.dart';

/// backend Singleton to provide all functionality related to the backend
class LocalMirror {
  // MARK: internals

  static final LocalMirror _instance = LocalMirror._internal();
  factory LocalMirror() => _instance;

  LocalMirror._internal() {
    // init
  }

  //final _imageStreamController = BehaviorSubject<String>();
  Stream<ImageData?> _fetchImage(String hash) async* {
    final img = await OP.readImage(hash);
    if (img == null) throw Exception("no img cached");
    yield ImageData(img, id: hash);
  }

  //final _imageStreamController = BehaviorSubject<String>();
  Future<ImageData?> _fetchImage_fut(String hash) async {
    final img = await OP.readImage(hash);
    if (img == null) throw Exception("no img cached");
    return ImageData(img, id: hash);
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

  /// Helper function to get the next [Data] (e.g. all [CheckPoint]s for chosen [CheckCategory])
  Future<List<ChildData>>
      _getAllForNextLevel<ChildData extends Data, ParentData extends Data>({
    required String route,
    required String jsonResponseID,
    Map<String, dynamic>? json,
    required ChildData? Function(Map<String, dynamic>) fromJson,
    String? id,
  }) async* {

    String _id = id ?? json?['local_id'] ?? await API().rootID;
    Map<String, dynamic> _json = {};
    Future<ChildData?> Function(Map<String, dynamic>) imageFetcher =
        _generateImageFetcher(fromJson);

    Future<List<ChildData>> __parse(__json) => getListFromJson(
          __json,
          imageFetcher,
          // _generateImageFetcher(fromJson),
          objName: jsonResponseID,
        );

    List<ChildData>? cached;
    if (Options().canBeOffline)
      try {
        final childD = await OP.getAllChildrenFrom<ChildData>(_id);
        _json =
            // {"$jsonResponseID": childD};
            // Ähhh ja die liste muss wie die response aussehen damit die function weiter unten die images fetchet
            jsonDecode("{\"$jsonResponseID\": ${jsonEncode(childD)}}");
        cached = await __parse(_json);
        yield cached;
      } catch (e) {
        debugPrint("couldnt read data from disk..: " + e.toString());
      }

    if (!_forceOffline ||
        Options().mergeOnlineEvenInCached)
      try {
        final res = (await post_JSON(RequestData(
          route,
          json: json,
          timeout: Duration(seconds: 10),
          ////logIfFailed: false,
        )));

        final body = res!.forceRes()!.body;
        _json = jsonDecode(body);
        var datapoints = await __parse(_json);
        yield datapoints;
        if ((Options().mergeOnline ||
                Options().mergeOnlineEvenInCached) &&
            cached != null) {
          try {
            cached.retainWhere(
                (element) => (element as WithOffline).forceOffline);
            var cachedIds = cached.map((element) => element.id).toList();
            datapoints.retainWhere((element) =>
                element.id != null && !cachedIds.contains(element.id));
            datapoints.addAll(cached);
            yield datapoints;
          } catch (e) {
            debugPrint("error merging data: " + e.toString());
          }
        }
        for (var data in datapoints) {
          String childId = await OP.storeData(data, forId: _id);
          if (Options().debugLocalMirror)
            debugPrint("stored new child with id: " + childId);
        }
      } catch (e) {
        debugPrint("couldnt reach API: " + e.toString());
      }

    if (Options().debugAllResponses)
      debugPrint("_getAllForNextLevel received: " + jsonEncode(json));
  }

  /// sends a [DataT] with the corresponding identifier to the given route
  Future<http.Response?> _sendDataToRoute<DataT extends Data>(
      {required DataT? data,
      required String route,
      Map<String, dynamic> other = const {},
      Helper.SimulatedRequestType? requestType,
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
      await connectionGuard(requestType: requestType);
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

  /// gets all the [ChildData]points for the given [ParentData]
  /// if no [ParentData] is given it defaults to root
  Future<List<ChildData>>
      getNextDatapoint<ChildData extends Data, ParentData extends WithOffline?>(
    ParentData data,
  ) async* {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.GET;
    if (!Options().canBeOffline)
      try {
        await connectionGuard(requestType: requestType);
      } catch (error) {
        showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
        yield [];
      }
    final childTypeStr = Helper.getIdentifierFromData<ChildData>(null);
    if (childTypeStr == null) throw Exception('type not supported');
    yield _getAllForNextLevel(
      route: routesFromData<ChildData>(null),
      jsonResponseID: childTypeStr + 's',
      json: data?.toSmallJson(),
      fromJson: (json) => /*Child*/ Data.fromJson<ChildData>(json),
      id: data?.id,
      forceOffline: data?.forceOffline,
    )
  }

  /// sets a new [DataT]
  Future<DataT?> setNew<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
    //offline procedure, needs some stuff changed and added..
    if (caller != null && data != null && caller.id != null) {
      data.id = /*'_on_' + */ (data.id ?? '__new__' + data.title);
      OP.storeData<DataT>(data, forId: caller.id!);
    }

    var body = (await _sendDataToRoute(
      requestType: requestType,
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
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;
    //offline procedure, needs some stuff changed and added..
    if ((forceUpdate || caller != null && caller.id != null) && data != null) {
      data.id = /*'_oe_' + */ (data.id ?? '__new__' + data.title);
      OP.storeData<DataT>(data, forId: caller?.id ?? await rootID);
    }

    return (await _sendDataToRoute(
      requestType: requestType,
      data: data,
      route: _update_r,
      // networkIsCrucial: requestType != Helper.SimulatedRequestType.GET,
    ))
        ?.body;
  }

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.DELETE;
    //TODO
    //offline procedure, needs some stuff changed and added..
    if (caller != null &&
        data != null &&
        caller.id != null &&
        data.id != null) {
      OP.deleteData<DataT>(data.id!, parentId: caller.id!);
    }

    return (await _sendDataToRoute(
      requestType: requestType,
      data: data,
      route: _delete_r,
      // networkIsCrucial: requestType != Helper.SimulatedRequestType.GET,
    ))
        ?.body;
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async {
    //TODO: #211
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.DELETE;
    await OP.deleteImage(hash);
    return (await post_JSON(RequestData(
      _deleteImageByHash_r,
      json: {'hash': hash},
      ////logIfFailed: requestType != Helper.SimulatedRequestType.GET,
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
    final Helper.SimulatedRequestType requestType =
        Helper.SimulatedRequestType.PUT;

    //TODO: #211
    //offline procedure, needs some stuff changed and added..
    if ((forceUpdate || caller != null && caller.id != null) && data != null) {
      try {
        data.id = /*'_oe_' + */ (data.id ?? '__new__' + data.title);
        data.imagehashes!.remove(hash);
        data.imagehashes!.insert(0, hash);
        OP.storeData<DataT>(data, forId: caller?.id ?? await rootID);
      } catch (e) {
        debugPrint('failed to update main image locally');
      }
    }
    return (await _sendDataToRoute(
      requestType: requestType,
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
      await connectionGuard(requestType: requestType);
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

  /// removes all locally stored images via [OP]
  final deleteCache = OP.deleteAll;

  Future<bool> retryFailedrequests(BuildContext? context) async {
    try {
      await connectionGuard(requestType: Helper.SimulatedRequestType.PUT);
    } catch (e) {
      showToast(S.current.noViableInternetConnection);
      return false;
    }
    final failedReqs = await OP.getAllFailedRequests() ?? [];
    bool success = true;
    for (final reqd in failedReqs) {
      final docID = reqd.item1;
      final rd = reqd.item2;
      if (rd != null)
        try {
          rd.////logIfFailed = false;
          final res = await LocalMirror().post_JSON(rd);
          //nur 200er als ok einstufen
          if (res!.statusCode == 200) {
            OP.failedRequestWasSuccessful(docID);
          } else {
            success = false;
            //TODO: what todo here?
            break;
          }
        } catch (e) {
          debugPrint('failed to retry request: $e');
          success = false;
        }
    }
    if (success && context != null) {
      final model = Provider.of<LocationModel>(context, listen: false);
      final locations = await model.all.last;
      for (final loc in locations) {
        final caller = CategoryModel(loc);
        await setOnlineAll(
          caller,
          3,
          name: caller.title,
          parentID: await rootID,
        );
      }
    }
    return success;
  }

  //TODO: das klappt zwar, aber das abspeichern selbst oder anzeigen nicht, wird aber OP liegen
  /// recursivle cache all elements that underly the caller
  Future<bool> loadAndCacheAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // base-case: CheckPointDefects have no children
    // if (typeOf<ChildData>() == CheckPointDefect) return true;//XXX: shit, this generic bums wont work
    if (depth == 0) return true;
    depth--;
    try {
      //fail early if no connection
      await connectionGuard(requestType: Helper.SimulatedRequestType.GET);
      //get all children, this will also cache them internally
      var children = await caller.all.last;
      var didSucceed = await Future.wait(children.map((child) async {
        String _name = '$name -> ${child.title}';
        debugPrint('__1234 got $depth: $_name');
        if (depth == 0)
          return true; //base-case as to not call generateNextModel
        bool child_succeeded = await loadAndCacheAll(
            caller.generateNextModel(child), depth,
            name: _name, parentID: caller.currentData.id);
        // try {

        // } catch (e) {}
        return child_succeeded;
      }));

      //if all children succeeded recursive calling succeeded
      bool success = didSucceed.every((el) => el);
      if (success) {
        caller.currentData.forceOffline = true;
        if (parentID == null) return false;

        try {
          var id = await OP.storeData(caller.currentData, forId: parentID);
          debugPrint(
              '_32 loading. ${depth + 1} stored : ${id}  ${caller.currentData.title}');
        } catch (e) {
          return false;
        }
      }

      return success;
    } catch (error) {
      debugPrint('failed! ${depth + 1}');
      showToast(error.toString() + "\n" + S.current.tryAgainLater_noNetwork);
      return false; //failed
    }
  }

  //this is probably more complicated than it needs to be, but it works (copied from loadAndCacheAll)
  Future setOnlineAll<
      ChildData extends WithLangText,
      ParentData extends WithOffline,
      DDModel extends DropDownModel<ChildData, ParentData>>(
    DDModel caller,
    int depth, {
    String? name,
    String? parentID,
  }) async {
    // base-case: CheckPointDefects have no children
    // if (typeOf<ChildData>() == CheckPointDefect) return true;//XXX: shit, this generic bums wont work
    if (depth == 0) return true;
    depth--;
    var children = await caller.all.last;
    caller.currentData.forceOffline = false;
    if (parentID != null) OP.storeData(caller.currentData, forId: parentID);
    final nextid = caller.currentData.id;
    for (final child in children) {
      String _name = '$name -> ${child.title}';
      debugPrint('__12342 got $depth: $_name');
      if (depth == 0) return; //base-case as to not call generateNextModel
      setOnlineAll(caller.generateNextModel(child), depth,
          name: _name, parentID: nextid);
    }
    ;
  }

  final storeData = OP.storeData;
  final getAllFailedRequests = OP.getAllFailedRequests;
  final failedRequestWasSuccessful = OP.failedRequestWasSuccessful;
  final logFailedReq = OP.logFailedReq;
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
