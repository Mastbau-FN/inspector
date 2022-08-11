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
          .map(
            (e) => injectImages(e),
          )
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
    //TODO
    //offline procedure, needs some stuff changed and added..
    if (caller != null &&
        data != null &&
        caller.id != null &&
        data.id != null) {
      OP.deleteData<DataT>(data.id!, parentId: caller.id!);
    }
  }

  //final _imageStreamController = BehaviorSubject<String>();
  Future<ImageData?> getImageByHash(String hash) async {
    final img = await OP.readImage(hash);
    if (img == null) throw Exception("no img cached");

    return ImageData(img, id: hash);
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
  final storeImage = OP.storeImage;
  final readImage = OP.readImage;
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
