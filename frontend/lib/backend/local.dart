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
  Future<List<ChildData>?>
      _getAllForNextLevel<ChildData extends Data, ParentData extends Data?>({
    Map<String, dynamic>? json,
    String? id,
  }) async {
    String _id = id ?? json?['local_id'] ?? await API().rootID;

    try {
      return (await OP.getAllChildrenFrom<ChildData>(_id))
          ?.whereType<ChildData>()
          .toList();
    } catch (e) {
      debugPrint("couldnt read data from disk..: " + e.toString());
    }
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
  ) async {
    final childTypeStr = Helper.getIdentifierFromData<ChildData>(null);
    if (childTypeStr == null) throw Exception('type not supported');
    return (await _getAllForNextLevel<ChildData, ParentData>(
          json: data?.toSmallJson(),
          id: data?.id,
        )) ??
        [];
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
      OP.storeData<DataT>(data, forId: caller?.id ?? await API().rootID);
    }
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
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash(String hash) async {
    //TODO: #211
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
        OP.storeData<DataT>(data, forId: caller?.id ?? await API().rootID);
      } catch (e) {
        debugPrint('failed to update main image locally');
      }
    }
  }

  /// upload a bunch of images
  Future<String?> uploadFiles<DataT extends Data>(
    DataT data,
    List<XFile> files,
  ) async {
    //TODO: #211
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
