import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/extension/map.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import '/classes/exceptions.dart';

import './offlineProvider.dart' as OP;
import './helpers.dart' as Helper;
import 'image_naming.dart';
import 'api.dart';

const LOCALLY_ADDED_PREFIX = '__loc__';

String _scopeForData(Data? data, {Data? caller}) {
  if (data == null) return '';
  String? parentId;
  try {
    parentId = (data as WithOffline).parentId;
  } catch (_) {}

  String inspection = data.id;
  String seg2 = 'undefined';
  String seg3 = 'undefined';
  String seg4 = 'undefined';

  if (data is CheckPointDefect) {
    inspection = data.pjNr.toString();
    seg2 = data.category_index.toString();
    seg3 = data.check_index.toString();
    seg4 = data.index.toString();
  } else if (data is CheckPoint) {
    inspection = data.pjNr.toString();
    seg2 = data.category_index.toString();
    seg3 = data.index.toString();
    seg4 = data.e3?.toString() ?? 'undefined';
  } else if (data is CheckCategory) {
    inspection = data.pjNr.toString();
    seg2 = data.index.toString();
    seg3 = data.e2?.toString() ?? 'undefined';
    seg4 = data.e3?.toString() ?? 'undefined';
  } else if (data is InspectionLocation) {
    inspection = data.pjNr.toString();
  } else if (parentId != null && parentId.isNotEmpty) {
    // Fallback for unknown/legacy data types.
    return parentId;
  } else if (caller is InspectionLocation) {
    inspection = caller.pjNr.toString();
  }

  // Only let caller override when we don't have a reliable numeric scope.
  if (inspection == data.id &&
      caller is WithOffline &&
      caller.parentId != null) {
    inspection = caller.parentId!;
  }

  if (inspection.isEmpty && parentId != null && parentId.isNotEmpty) {
    return parentId;
  }
  if (inspection.isEmpty) return '';
  // use "undefined" as canonical folder token
  return [inspection, seg2, seg3, seg4]
      .join('-')
      .replaceAll('null', 'undefined');
}

/// backend Singleton to provide all functionality related to the backend
class LocalMirror {
  // MARK: internals

  static final LocalMirror _instance = LocalMirror._internal();
  factory LocalMirror() => _instance;

  LocalMirror._internal() {
    // init
  }

  /// Returns folder scope for given data (e.g. pjNr-E1-E2-E3)
  String scopeFor(Data? data, {Data? caller}) =>
      _scopeForData(data, caller: caller);

  Future<List<String>> listScopedImageNames(Data? data, {Data? caller}) async {
    final scope = _scopeForData(data, caller: caller).trim();
    if (scope.isEmpty) return const [];
    try {
      return await OP.listScopedImageNames(scope);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _deleteStoredImageQuietly(String storedName) async {
    final name = storedName.trim();
    if (name.isEmpty) return;
    try {
      final file = await OP.localFile(name);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
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
    debugPrint(data.toString());
    if (
        // (forceUpdate ||
        //       caller != null ||
        //       typeOf<DataT>() == typeOf<InspectionLocation>()) &&
        data != null) {
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
  Future<ImageData?> getImageByHash(String hash, {Data? owner}) async {
    final isPath = hash.contains('/');
    final scope = _scopeForData(owner);
    final legacyScope = scope.contains('undefined')
        ? scope.replaceAll('undefined', 'null')
        : scope;

    String displayNameFromStored(String storedName) {
      var base = storedName.split('/').where((e) => e.isNotEmpty).toList().last;
      // strip prefixes
      if (base.startsWith(LOCALLY_ADDED_PREFIX)) {
        base = base.substring(LOCALLY_ADDED_PREFIX.length);
      }
      // strip common extensions
      final lower = base.toLowerCase();
      const suffixes = [
        '.maybe.jpg',
        '.img',
        '.jpeg',
        '.jpg',
        '.webp',
        '.heic',
        '.png',
      ];
      for (final s in suffixes) {
        if (lower.endsWith(s)) {
          return base.substring(0, base.length - s.length);
        }
      }
      final dot = base.lastIndexOf('.');
      if (dot > 0 && dot > base.length - 8) return base.substring(0, dot);
      return base;
    }

    // Prefer the backend filename-based cache if present.
    if (!isPath) {
      try {
        final indexed = await OP.lookupImageNameForHash(
          hash,
          scope: scope,
        );
        if (indexed != null && indexed.isNotEmpty) {
          final img = await readImage(indexed, cacheSize: null);
          if (img != null)
            return ImageData(img,
                id: hash, name: displayNameFromStored(indexed));
        }
      } catch (_) {}
    }

    List<String> candidates = [];
    if (!isPath && scope.isNotEmpty) {
      final scoped = '$scope/$hash';
      candidates.add(scoped);
    }
    if (!isPath && legacyScope.isNotEmpty && legacyScope != scope) {
      final scoped = '$legacyScope/$hash';
      candidates.add(scoped);
    }
    candidates.add(hash);

    for (final name in candidates) {
      final img = await readImage(name, cacheSize: null);
      if (img != null) {
        // Best-effort migration: if we loaded from a legacy "null" folder, copy to the
        // canonical "undefined" folder so we stop accumulating both.
        if (!isPath &&
            scope.isNotEmpty &&
            legacyScope != scope &&
            name.startsWith('$legacyScope/')) {
          final migratedName = name.replaceFirst(legacyScope, scope);
          try {
            final src = await OP.localFile(name);
            final dst = await OP.localFile(migratedName);
            if (!dst.existsSync()) {
              await dst.parent.create(recursive: true);
              await src.copy(dst.path);
            }
            await OP.indexImageHash(
              hash: hash,
              storedName: migratedName,
              scope: scope,
            );
            final migratedImg = await readImage(migratedName, cacheSize: null);
            if (migratedImg != null) {
              return ImageData(migratedImg,
                  id: hash, name: displayNameFromStored(migratedName));
            }
          } catch (_) {}
        }
        return ImageData(img, id: hash, name: displayNameFromStored(name));
      }
    }
    throw Exception("no img cached");
  }

  Future<File?> getDocument(String docPath, {String? scope}) async {
    final filename = docPath.split('/').last;
    final s = (scope ?? '').trim();
    final legacyScope =
        s.contains('undefined') ? s.replaceAll('undefined', 'null') : s;

    final candidates = <String>[
      if (s.isNotEmpty) '$s/Dokus/$filename',
      if (legacyScope.isNotEmpty && legacyScope != s)
        '$legacyScope/Dokus/$filename',
      // legacy: flat storage
      filename,
    ];

    for (final name in candidates) {
      final doc = await readDoc(name);
      if (doc != null) return doc;
    }
    throw Exception("no doc cached");
  }

  /// deletes an image specified by its hash and returns the response
  Future<String?> deleteImageByHash<DataT extends Data>(
    DataT? data,
    String hash, {
    String? canonicalHash,
    Data? caller,
    bool forceUpdate = false,
  }) async {
    final requested = hash.trim();
    final canonical = (canonicalHash ?? '').trim();
    final scope = _scopeForData(data, caller: caller).trim();

    final hashRefs = <String>{};
    final pathRefs = <String>{};

    void addRef(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (v.contains('/')) {
        pathRefs.add(v);
      } else {
        hashRefs.add(v);
      }
    }

    addRef(requested);
    addRef(canonical);

    for (final ref in [requested, canonical]) {
      if (ref.isEmpty || !ref.contains('/')) continue;
      try {
        final mappedHash = await OP.lookupHashForImageName(ref, scope: scope);
        if (mappedHash != null && mappedHash.trim().isNotEmpty) {
          addRef(mappedHash);
        }
      } catch (_) {}
    }

    for (final h in hashRefs.toList(growable: false)) {
      try {
        final mappedName = await OP.lookupImageNameForHash(h, scope: scope);
        if (mappedName != null && mappedName.trim().isNotEmpty) {
          addRef(mappedName);
        }
      } catch (_) {}
      if (scope.isNotEmpty) addRef('$scope/$h');
    }

    final allRefs = <String>{...hashRefs, ...pathRefs};

    if ((forceUpdate || caller != null) && data != null) {
      try {
        data.imagehashes ??= <String>[];
        data.imagehashes!.removeWhere((h) => allRefs.contains(h));
        if (data.mainhash != null && allRefs.contains(data.mainhash!)) {
          data.mainhash = null;
        }
        await storeData<DataT>(data, forId: caller?.id ?? await API().rootID);
      } catch (e) {
        debugPrint('failed to remove image references locally: $e');
      }
    }

    for (final pathRef in pathRefs) {
      await _deleteStoredImageQuietly(pathRef);
    }
    for (final hashRef in hashRefs) {
      await _deleteStoredImageQuietly(hashRef);
      if (scope.isNotEmpty) {
        await _deleteStoredImageQuietly('$scope/$hashRef');
      }
      await OP.unindexImageHash(hash: hashRef, scope: scope);
    }
    return 'success';
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
    final scope = _scopeForData(data, caller: caller);
    String _scoped(String base) => scope.isNotEmpty ? '$scope/$base' : base;
    await Future.wait(files.map((file) async {
      final bytes = await file.readAsBytes();
      final imageName = _scoped(canonicalTimestampFilenameForXFile(file));
      await storeImage(bytes, imageName);
      newLocalImageNames.add(imageName);
    }));
    if (data.imagehashes == null) data.imagehashes = [];
    if (data.imagehashes!.isEmpty && data.mainhash == null) {
      data.mainhash = newLocalImageNames.first;
      newLocalImageNames.removeAt(0);
    }
    data.imagehashes?.addAll(newLocalImageNames);
    injectImages(data, preloadFull: true);
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
  final storeDoc = OP.storeDoc;
  final readDoc = OP.readDoc;
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
        S.current!.couldNotParseResponse + jsonEncode(json));
  }
  //return [];
}
