import 'dart:core';
import 'dart:io';
import 'dart:typed_data';

import 'package:MBG_Inspektionen/assets/consts.dart';
import 'package:tuple/tuple.dart';

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
    if (Options.debugLocalMirror) debugPrint('saved ${file}');
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

  //create a new document with new id if wanted
  final id = (override && oldId != null)
      ? oldId
      : db.collection(collectionName).doc().id;

  if (addId) json['local_id'] = id;
  if (Options.debugLocalMirror) debugPrint("stored json: " + json.toString());
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
      .toList();
}

final failedReqLogCollection = (db).collection('failed-requests');

Future<String> logFailedReq<T extends http.BaseRequest>(T req) async {
  final doc = failedReqLogCollection.doc();

  ///TODO: idk if this uses the baserquest to json, which it shouldnt..
  await doc.set(req.toJson);
  return doc.id;
}

///returns a List of weird structures of the id of the failed request and a tuple where exactly one is null, either a [http.Response] or an [http.MultipartRequest]
Future<List<Tuple2<String, Tuple2<http.Request?, http.MultipartRequest?>>>?>
    getAllFailedRequests() async {
  requestFromJson(Map<String, dynamic> json) async {
    switch (json['type']) {
      case 'Request':
        return Tuple2(
            http.Request(json['method'], Uri.parse(json['url']))
              ..headers.addAll(json['headers'])
              ..encoding = json['encoding']
              ..body = json['body'],
            null);
      case 'MultipartRequest':
        return Tuple2(
            null,
            http.MultipartRequest(json['method'], Uri.parse(json['url']))
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
              ));
      default:
        throw UnimplementedError();
    }
  }

  final docs = (await failedReqLogCollection
      .get()); //TODO: das muss in-order sein, sonst könnte es probleme geben..

  return (docs == null)
      ? null
      : Future.wait(docs.entries
          .map((e) async => Tuple2(e.key, await requestFromJson(e.value))));
}

failedRequestWasSuccesful(String id) {
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

// extension DeserializableRequest<T extends http.BaseRequest> on T {
//   static T fromJson(Map<String, dynamic> json) => requestFromJson(json) as T;

//   static requestFromJson(Map<String, dynamic> json) async {
//     switch (json['type']) {
//       case 'Request':
//         return http.Request(json['method'], Uri.parse(json['url']))
//           ..headers.addAll(json['headers'])
//           ..encoding = json['encoding']
//           ..body = json['body'];
//       case 'MultipartRequest':
//         return http.MultipartRequest(json['method'], Uri.parse(json['url']))
//           ..headers.addAll(json['headers'])
//           ..fields.addAll(json['body'])
//           ..files.addAll(
//             List<http.MultipartFile>.from((await Future.wait(
//               json['file-names'].map(
//                 (String name) async => http.MultipartFile.fromPath(
//                     'package',
//                     (await _localFile(name))
//                         .path), //TO-DO: eventuell macht hier das .img im _localfile ein problem, da es im name wahrscheinlich schon enthalten ist idk, muss getestet werden
//               ),
//             ))
//                 .whereType<http.MultipartFile>()),
//           );
//       default:
//         throw UnimplementedError();
//     }
//   }
// }
