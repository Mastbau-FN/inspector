import 'dart:async';
import 'dart:convert';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/extension/map.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '/classes/exceptions.dart';

import './offlineProvider.dart' as OP;
import './helpers.dart' as Helper;
import 'api.dart';

const LOCALLY_ADDED_PREFIX = '__locally_added__';

const CACHESIZE = 128;

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
      return null;
    }
  }

  // void _maybeShowToast(String? message) {
  //   if (message != null && message != "") {
  //     showToast(message);
  //   }
  // }

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
    if (caller != null && data != null) {
      final author = (await API().user)!.name;
      try {
        if ((caller as WithOffline).forceOffline)
          (data as WithOffline).forceOffline = true;
      } catch (e) {}
      data = Data.fromJson<DataT>(data.toJson().copyWith({
        'Autor': author,
        // 'local_id':
        //     LOCALLY_ADDED_PREFIX + UniqueKey().hashCode.toRadixString(36)
      }))!; //kinda hacky
      await storeData<DataT>(data, forId: caller.id);
      return data;
    }
    return null;
  }

  /// updates a [DataT] and returns the response
  Future<String?> update<DataT extends Data>(
    DataT? data, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    //offline procedure, needs some stuff changed and added..
    if ((forceUpdate || caller != null) && data != null) {
      await storeData<DataT>(data, forId: caller?.id ?? await API().rootID);
      return 'success';
    }
    return null;
  }

  /// deletes a [DataT] and returns the response
  Future<String?> delete<DataT extends Data>(
    DataT? data, {
    Data? caller,
  }) async {
    //offline procedure, needs some stuff changed and added..
    if (caller != null && data != null) {
      await OP.deleteData<DataT>(data.id, parentId: caller.id);
      return 'success';
    }
    return null;
  }

  //final _imageStreamController = BehaviorSubject<String>();
  Future<ImageData?> getImageByHash(String hash,
      {bool compressed = false}) async {
    if (compressed) hash = OP.convertToCompressedHashName(hash);
    final img = await readImage(hash, cacheSize: compressed ? CACHESIZE : null);
    if (img == null) throw Exception("no img cached");
    // return null;

    return ImageData(img, id: hash);
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    //offline procedure, needs some stuff changed and added..
    if ((forceUpdate || caller != null) && data != null) {
      try {
        // data.id = /*'_oe_' + */ createLocalId(data);
        await OP.deleteImage(hash);
        data.imagehashes!.remove(hash);
        await storeData<DataT>(data, forId: caller?.id ?? await API().rootID);
        // return 'successfully deleted image offline';
      } catch (e) {
        debugPrint('failed to remove image locally');
      }
    }
    return null;
  }

  /// sets an image specified by its hash as the new main image
  Future<String?> setMainImageByHash<DataT extends Data>(
    DataT? data,
    String mainhash, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    //offline procedure, needs some stuff changed and added..
    if ((forceUpdate || caller != null) && data != null) {
      try {
        // remove new main image from list
        data.imagehashes!.remove(mainhash);
        //reinstert old main image to list
        if (data.mainhash != null) data.imagehashes!.insert(0, data.mainhash!);
        //set new main image
        data.mainhash = mainhash;

        debugPrint('set main image hash to $mainhash');

        await storeData<DataT>(data, forId: caller?.id ?? await API().rootID);
        // return 'successfully set main image offline';
      } catch (e) {
        debugPrint('failed to update main image locally');
      }
    }
    return null;
  }

  /// upload a bunch of images
  Future<String?> uploadNewImagesOrFiles<DataT extends Data>(
    DataT data,
    List<XFile> files, {
    Data? caller,
    bool forceUpdate = false,
  }) async {
    List<String> newLocalImageNames = [];
    await Future.wait(files.map((file) async {
      final bytes = await file.readAsBytes();
      final imageName = '$LOCALLY_ADDED_PREFIX${file.name}';
      await storeImage(bytes, imageName);
      newLocalImageNames.add(imageName);
    }));
    if (data.imagehashes == null) data.imagehashes = [];
    if (data.imagehashes!.isEmpty && data.mainhash == null) {
      data.mainhash = newLocalImageNames.first;
      newLocalImageNames.removeAt(0);
    }
    data.imagehashes?.addAll(newLocalImageNames);
    injectImages(data);
    await storeData(data, forId: caller?.id ?? await API().rootID);
    // NewImages.addAllNulled(newLocalImageNames);
    return 'added files offline';
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
        AppLocalizations.of(context)!.couldNotParseResponse + jsonEncode(json));
  }
  //return [];
}
