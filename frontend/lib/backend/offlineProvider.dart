import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import 'package:localstore/localstore.dart';

import './helpers.dart' as Helper;

// MARK: image stuff

Future<String> get _localPath async =>
    (await getApplicationDocumentsDirectory()).path;

Future<File> _localFile(String name) async =>
    File('${await _localPath}/${name.replaceAll(RegExp(r'[^\w]+'), '_')}.img');

/// stores the [imgBytes] as an image given by the [name], returns the new [File]
Future<File?> storeImage(Uint8List imgBytes, String name) async {
  var file = await _localFile(name);

  // Write the file
  try {
    //file = (await file.exists()) ? file : await file.create();
    file = await file.writeAsBytes(imgBytes); //u good?
    debugPrint('saved ${file}');
    return file;
  } catch (e) {
    debugPrint("!!! failed to store image: " + e.toString());
    return null;
  }
}

///tries to open an [Image] given by its [name] and returns it if succesfull
Future<Image?> readImage(String name) async {
  final file = (await _localFile(name));
  if (!file.existsSync()) throw Exception("file ${file} doesnt exist");
  if (file.lengthSync() < 5)
    throw Exception("file ${file} definitely to small");
  //TODO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  //debugPrint("retrieving ${file}");
  return Image.file(await _localFile(name));
}

///tries to remove an [Image] given by its [name] , throws if unsuccesfull
Future<File> deleteImage(String name) async {
  final file = (await _localFile(name));
  if (!file.existsSync()) throw Exception("file ${file} doesnt exist");

  return await file.delete() as File;
}

deleteAll() async => Directory(await _localPath).delete();

//MARK: data-stuff

final db = Localstore.instance;

/// non-null wrapper for [Helper.getIdentifierFromData]
/// a collection is always named via the scheme `${DataT}-${ParentId}`
String _getCollectionNameForData<DataT extends Data>(String parentId) {
  final dataName = Helper.getIdentifierFromData<DataT>(null);
  if (dataName == null) throw Exception('could not get collection ${dataName}');
  return dataName + '-' + parentId;
}

/// permanently stores a DataT in its corresponding collection
Future<String> storeData<DataT extends Data>(DataT data,
    {required String forId, bool addId = true, bool override = true}) async {
  final collectionName = _getCollectionNameForData<DataT>(forId);

  var json = data.toJson();
  String? oldId = json['local_id'];

  final id = (override && oldId != null)
      ? oldId
      : db.collection(collectionName).doc().id;

  if (addId) json['local_id'] = id;
  //debugPrint("stored json: " + json.toString());
  db.collection(collectionName).doc(id).set(json);

  return forId + '-' + id;
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
      .toList();
}

final failedReqLogCollection = (db).collection('failed-requests');

logFailedPostReq(http.Request req) {
  final doc = failedReqLogCollection.doc();
  return doc.set(req.toJson);
}

logFailedMultiReq(http.MultipartRequest req) {
  final doc = failedReqLogCollection.doc();
  return doc.set(req.toJson);
}

extension SerializableRequest on http.Request {
  ////very unpolished version that only works for my kind of post req
  Map<String, dynamic> get toJson => {
        'type': 'Request',
        'url': this.url,
        'headers': this.headers,
        'body': this.body,
        'encoding': this.encoding,
        'method': this.method,
      };

  static http.Request fromJson(Map<String, dynamic> json) =>
      requestFromJson(json) as http.Request;
}

extension SerializableMultiPartReq on http.MultipartRequest {
  ////very unpolished version that only works for my kind of post req
  Map<String, dynamic> get toJson => {
        'type': 'MultipartRequest',
        'url': this.url,
        'headers': this.headers,
        'body': this.fields,
        'file-names': this.files.map((e) => e.filename).toList(),
        'method': this.method,
      };

  static http.MultipartRequest fromJson(Map<String, dynamic> json) =>
      requestFromJson(json) as http.MultipartRequest;
}

// extension DeserializableRequest on http.BaseRequest{
// factory requestFromJson(Map<String,dynamic> json ){
requestFromJson(Map<String, dynamic> json) async {
  switch (json['type']) {
    case 'Request':
      return http.Request(json['method'], Uri.parse(json['url']))
        ..headers.addAll(json['headers'])
        ..encoding = json['encoding']
        ..body = json['body'];
    case 'MultipartRequest':
      return http.MultipartRequest(json['method'], Uri.parse(json['url']))
        ..headers.addAll(json['headers'])
        ..fields.addAll(json['body'])
        ..files.addAll(
          List<http.MultipartFile>.from((await Future.wait(
            json['file-names'].map(
              (String name) async => http.MultipartFile.fromPath(
                  'package',
                  (await _localFile(name))
                      .path), //TODO: eventuell macht hier das .img im _localfile ein problem, da es im name wahrscheinlich schon enthalten ist idk, muss getestet werden
            ),
          ))
              .whereType<http.MultipartFile>()),
        );
      break;
    default:
      throw UnimplementedError();
  }
}
// }
