import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

Future<String> get _localPath async =>
    (await getApplicationDocumentsDirectory()).path;

Future<File> _localFile(String name) async =>
    File('${await _localPath}/${name.replaceAll(RegExp(r'[^\w]+'), '_')}.img');

Future<XFile?> storeImage(Uint8List imgBytes, String name) async {
  var file = await _localFile(name);

  // Write the file
  try {
    (await file.exists()) ? file : await file.create();
    await file.writeAsBytes(imgBytes); //warum gehst du nicht :(
    debugPrint(file.path);
    return XFile(file.path);
  } catch (e) {
    debugPrint("failed to store image: " + e.toString());
    return null;
  }
}

Future<Image?> readImage(String name) async {
  if (await (await _localFile(name)).exists())
    throw Exception("file doesnt exist");
  //TODO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  return Image.file(await _localFile(name));
}

deleteAll() async => Directory(await _localPath).delete();
