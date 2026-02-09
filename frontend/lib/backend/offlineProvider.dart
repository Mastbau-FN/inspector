import 'dart:core';
import 'dart:convert';
import 'dart:io';

import 'package:MBG_Inspektionen/options.dart';
import 'package:MBG_Inspektionen/classes/requestData.dart';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:io/io.dart';
import 'package:path_provider/path_provider.dart';

import 'package:localstore/localstore.dart';

import './helpers.dart' as Helper;

const useOldImgEncoding =
    false; //TO-DO: reset after partiks incident was solved to false

// MARK: image stuff

Future<String> get localPath async {
  if (kIsWeb) return "okay_we_need_to_fake_it_for_web/"; //TODO
  return (await getApplicationDocumentsDirectory()).path;
}

Future<File> localFile(String name, [String? doc]) async {
  // allow nested relative paths (e.g. per inspection) and create dirs if needed
  final basePath = await localPath;
  var p0 = File('$basePath/$name');
  // keep legacy behaviour only for flat names; otherwise preserve folders
  final hasFolder = name.contains('/');

  if (doc != null) {
    await p0.parent.create(recursive: true);
    return p0;
  }

  if (await p0.exists()) return p0;
  if (hasFolder) {
    // if the file has no extension, prefer a .jpg to keep it recognizable
    final baseName = p0.uri.pathSegments.last;
    if (!baseName.contains('.')) {
      final withExt = File('$basePath/$name.jpg');
      return withExt;
    }
    await p0.parent.create(recursive: true);
    return p0;
  }

  final sanitized =
      name.replaceAll(RegExp(r'[^\w]+'), '_'); // legacy naming fallback
  final p1 = File('$basePath/$sanitized.img');
  if (await p1.exists() || useOldImgEncoding) {
    await p1.parent.create(recursive: true);
    return p1;
  }
  final p2 = File('$basePath/$sanitized.maybe.jpg');
  await p2.parent.create(recursive: true);
  return p2;
}

/// stores the [imgBytes] as an image given by the [name], returns the new [File]
Future<File?> storeImage(Uint8List imgBytes, String name) async {
  // Write the file
  try {
    var file = await localFile(name);
    await file.parent.create(recursive: true);
    // if (kIsWeb) {
    //TODO: support storing images/file in indexedDb or something for web
    // } else
    file = await file.writeAsBytes(imgBytes); //u good?
    debugPrint('Stored image at ${file.path}');
    return file;
  } catch (e) {
    debugPrint("!!! failed to store image: " + e.toString());
    return null;
  }
}

Future<File?> storeDoc(Uint8List imgBytes, String name) async {
  // Write the file
  try {
    var file = await localFile(name, "jaman");
    await file.parent.create(recursive: true);
    file = await file.writeAsBytes(imgBytes); //u good?
    return file;
  } catch (e) {
    debugPrint("!!! failed to store image: " + e.toString());
    return null;
  }
}

class NoImagePlaceholderException implements Exception {
  @override
  String toString() =>
      'tried to read the placeholder image, which of course is not there';
}

String convertToCompressedHashName(String hash) => 'compressed/$hash';

///tries to open an [Image] given by its [name] and returns it if successful
Future<Image?> readImage(String name, {int? cacheSize}) async {
  //TODO: support reading images/file from indexedDb or something for web

  final file = (await localFile(
    name,
  ));
  // ignore: unused_local_variable
  final err = (name == Options().no_image_placeholder_name)
      ? NoImagePlaceholderException()
      : Exception("file $file doesnt exist");
  if (!file.existsSync())
    // throw err;
    return null;
  if (file.lengthSync() < 5) throw Exception("file $file definitely to small");
  //TO-DO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  return Image.file(await localFile(name),
      cacheHeight: cacheSize, cacheWidth: cacheSize);
}

/// Tries to resolve an existing on-disk image file for a given hash/name.
/// Supports scoped paths (`<scope>/<hash>`), compressed variants, and legacy naming.
Future<File?> resolveImageFileByHash(
  String hash, {
  String? scope,
  bool compressed = false,
  bool allowCompressedFallback = true,
}) async {
  final isPath = hash.contains('/');
  final names = <String>[];

  String baseName(String h, {required bool c}) =>
      c ? convertToCompressedHashName(h) : h;

  void add(String n) {
    if (n.isEmpty) return;
    names.add(n);
  }

  if (!isPath && scope != null && scope.isNotEmpty) {
    add('$scope/${baseName(hash, c: compressed)}');
  }
  add(baseName(hash, c: compressed));
  add(hash);

  if (!compressed && allowCompressedFallback) {
    if (!isPath && scope != null && scope.isNotEmpty) {
      add('$scope/${baseName(hash, c: true)}');
    }
    add(baseName(hash, c: true));
  }

  for (final name in names) {
    try {
      final f = await localFile(name);
      if (f.existsSync()) return f;
    } catch (_) {}
  }
  return null;
}

Future<File?> readDoc(String name, {int? cacheSize}) async {
  //TODO: support reading images/file from indexedDb or something for web

  final file = (await localFile(name, "jaman"));
  // ignore: unused_local_variable
  final err = (name == Options().no_image_placeholder_name)
      ? NoImagePlaceholderException()
      : Exception("file $file doesnt exist");
  if (!file.existsSync())
    // throw err;
    return null;
  if (file.lengthSync() < 5) throw Exception("file $file definitely to small");
  //TO-DO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  return await localFile(name);
}

///tries to remove an [Image] given by its [name] , throws if unsuccessful
Future<File> deleteImage(String name) async {
  //TODO: support web
  final file = (await localFile(name));
  if (!file.existsSync()) throw Exception("file $file doesnt exist");

  return await file.delete() as File;
}

Future<void> deleteAll({
  bool keepSkippedRequests = false,
}) async {
  final root = await getApplicationDocumentsDirectory();
  final cache = await getApplicationCacheDirectory();
  if (keepSkippedRequests) {
    copyPath(root.path + "/" + SKIPPEDCOLLECTION,
        cache.path + "/" + SKIPPEDCOLLECTION);
    await deleteAll();
    copyPath(cache.path + "/" + SKIPPEDCOLLECTION,
        root.path + "/" + SKIPPEDCOLLECTION);
  } else {
    root.delete(recursive: true);
  }
}

//MARK: data-stuff

final db = Localstore.instance;

const IMAGE_INDEX_COLLECTION = 'image-index';
final imageIndexCollection = (db).collection(IMAGE_INDEX_COLLECTION);

String _imageIndexDocId(
  String hash, {
  required bool compressed,
  String? scope,
}) {
  final s = (scope ?? '').trim();
  final key = '${compressed ? 'c' : 'o'}|$s|$hash';
  // Localstore doc ids are path-like; keep it filesystem-safe and reasonably short.
  return base64UrlEncode(utf8.encode(key)).replaceAll('=', '');
}

Future<void> indexImageHash({
  required String hash,
  required String storedName,
  required bool compressed,
  String? scope,
}) async {
  final id = _imageIndexDocId(hash, compressed: compressed, scope: scope);
  await imageIndexCollection.doc(id).set({
    'hash': hash,
    'storedName': storedName,
    'compressed': compressed,
    'scope': scope ?? '',
    'ts': DateTime.now().millisecondsSinceEpoch,
  });
}

Future<String?> lookupImageNameForHash(
  String hash, {
  required bool compressed,
  String? scope,
}) async {
  final scopedId = _imageIndexDocId(hash, compressed: compressed, scope: scope);
  final scoped = await imageIndexCollection.doc(scopedId).get();
  final scopedName = scoped?['storedName']?.toString();
  if (scopedName != null && scopedName.isNotEmpty) return scopedName;

  // fallback: global entry (no scope)
  final globalId = _imageIndexDocId(hash, compressed: compressed, scope: '');
  final global = await imageIndexCollection.doc(globalId).get();
  final globalName = global?['storedName']?.toString();
  if (globalName != null && globalName.isNotEmpty) return globalName;

  return null;
}

/// @depricated, its now only the parentID
/// ~~non-null wrapper for [Helper.getIdentifierFromData]~~
/// ~~a collection is always named via the scheme `${DataT}-${ParentId}`~~
String _getCollectionNameForData<DataT extends Data>(String parentId) {
  return parentId;
  // final dataName = Helper.getIdentifierFromData<DataT>(null);
  // if (dataName == null) throw Exception('could not get collection $dataName');
  // return dataName + '-' + parentId;
}

enum OverrideMode { abortIfExistent, update, createNew }

/// permanently stores a DataT in its corresponding collection
Future<String> storeData<DataT extends Data>(
  DataT data, {
  required String forId,
  bool addId = true,
  OverrideMode overrideMode = OverrideMode.update,
}) async {
  final collectionName = _getCollectionNameForData<DataT>(forId);

  var json = data.toJson();
  String? oldId = data.id;

  final isExistent = ((await db.collection(collectionName).get())
          ?.keys
          .contains('/$collectionName/$oldId')) ??
      false;
  if (overrideMode == OverrideMode.abortIfExistent && isExistent) {
    debugPrint('wont override $oldId');
    return '';
  }

  //create a new document with new id if wanted
  final id = (!isExistent || overrideMode == OverrideMode.update)
      ? oldId
      : db.collection(collectionName).doc().id;

  if (addId) json['local_id'] = id;
  db.collection(collectionName).doc(id).set(json);

  return id;
}

/// retrieves a DataT via its [id] and corresponding [parentId]
Future<DataT?> retrieveData<DataT extends Data>(String id,
    {required String parentId}) async {
  final collectionName = _getCollectionNameForData<DataT>(parentId);
  final data = await db.collection(collectionName).doc(id).get();
  return Data.fromJson<DataT>(data ?? {});
}

/// deletes a DataT via its [id] and corresponding [parentId]
Future deleteData<DataT extends Data>(String id,
    {required String parentId}) async {
  final collectionName = _getCollectionNameForData<DataT>(parentId);
  final ret = await db.collection(collectionName).doc(id).delete();
  return ret;
}

/// this is probably the most used in this project
/// it returns all [Data] ([ChildData]) -points that correspond to the [ParentData] with given [id]
Future<List<ChildData?>?> getAllChildrenFrom<ChildData extends Data>(
    String id) async {
  final collectionName = _getCollectionNameForData<ChildData>(id);
  final items = await db.collection(collectionName).get();
  return items?.values
          .map((data) => Data.fromJson<ChildData>(data ?? {}))
          .toList() ??
      [];
}

const OTHERCOLLECTION = 'other';
final otherCollection = (db).collection(OTHERCOLLECTION);
storeJson(String documentName, Map<String, dynamic> json) =>
    otherCollection.doc(documentName).set(json);

Future<Map<String, dynamic>?> getJson(String documentName) =>
    otherCollection.doc(documentName).get();

const FAILEDCOLLECTION = 'failed-requests';
const SKIPPEDCOLLECTION = 'skipped-requests';
final failedReqLogCollection = (db).collection(FAILEDCOLLECTION);
final skippedReqLogCollection = (db).collection(
    SKIPPEDCOLLECTION); //bei fragen zu logik hierzu hannes fragen, war sein commit

Future<String> logFailedReq(RequestData rd) async {
  final doc = failedReqLogCollection
      .doc(DateTime.now().millisecondsSinceEpoch.toRadixString(36));

  //TO-DO: idk if this uses the baserquest to json, which it shouldnt.. yes, it did
  await doc.set(await rd.serialized);
  return doc.id;
}

///returns a List of weird structures of the id of the failed request and a tuple where exactly one is null, either a [http.Response] or an [http.MultipartRequest]
Future<List<(String, RequestData?)>?> getAllFailedRequests() async {
  final docs = (await failedReqLogCollection
      .get()); //TO-DO: das muss in-order sein, sonst könnte es probleme geben..

  if (docs == null) return null;
  final docsWithTimeStr =
      docs.map((key, value) => MapEntry(key.split('/').last, value));
  final docsWithTimeAsFutureTuples = docsWithTimeStr.entries.map((e) async {
    try {
      final parsedReq = RequestData.deserialize(e.value);
      return (e.key, parsedReq);
    } catch (err) {
      debugPrint('failed parse of request hm, $err');
    }
    return (e.key, null);
  });
  var reqs = (await Future.wait(docsWithTimeAsFutureTuples));
  reqs.sort((a, b) =>
      int.parse(a.$1, radix: 36).compareTo(int.parse(b.$1, radix: 36)));
  return reqs;
}

failedRequestWasSuccessful(String id, {bool wasntTho = false}) {
  if (wasntTho) {
    //hannes
    failedReqLogCollection.doc(id).get().then((data) {
      if (data == null) {
        debugPrint('request $id wasnt in the failed-Log');
        return;
      }
      skippedReqLogCollection.doc(id).set(data);
      debugPrint('request $id was skipped and moved to skipped-Log');
    });
  }
  failedReqLogCollection.doc(id).delete();
  debugPrint(
      'request $id was apperently successful, so we deleted it from the failed-Log');
}

extension SerializableBaseRequest on http.BaseRequest {
  Map<String, dynamic> get toJson => {
        'type': 'Request',
        'url': this.url.toString(),
        'headers': this.headers,
        'method': this.method,
      };
}

extension SerializableRequest on http.Request {
  ////very unpolished version that only works for my kind of post req
  Map<String, dynamic> get toJson => {
        'type': 'Request',
        'url': this.url.toString(),
        'headers': this.headers,
        'body': this.body,
        'encoding': this.encoding,
        'method': this.method,
      };

  // static http.Request fromJson(Map<String, dynamic> json) =>
  //     requestFromJson(json) as http.Request;
}

extension SerializableMultiPartReq on http.MultipartRequest {
  ////very unpolished version that only works for my kind of post req
  Map<String, dynamic> get toJson => {
        'type': 'MultipartRequest',
        'url': this.url.toString(),
        'headers': this.headers,
        'body': this.fields,
        'file-names': this.files.map((e) => e.filename).toList(),
        'method': this.method,
      };

  // static http.MultipartRequest fromJson(Map<String, dynamic> json) =>
  //     requestFromJson(json) as http.MultipartRequest;
}

Future<String> permaStoreCachedXFile(XFile file, [String? _name]) async {
  final basePath = await localPath;
  // prefer keeping relative folder if the file already lives in our app dir
  String? relativeName;
  if (file.path.startsWith(basePath)) {
    relativeName = file.path.substring(basePath.length + 1);
  }
  final name = _name ?? relativeName ?? file.name;
  final target = await localFile(name);
  await target.parent.create(recursive: true);
  await file.saveTo(target.path);
  debugPrint('Persisted cached file to ${target.path}');
  return name;
}

Future<XFile> retrieveStoredXFile(String name) async {
  return XFile((await localFile(name)).path);
}
