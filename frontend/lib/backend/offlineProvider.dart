import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

Future<String> get _localPath async =>
    (await getApplicationDocumentsDirectory()).path;

Future<File> _localFile(String name) async =>
    File('${await _localPath}/${name.replaceAll(RegExp(r'[^\w]+'), '_')}.img');

Future<File?> storeImage(Uint8List imgBytes, String name) async {
  var file = await _localFile(name);

  // Write the file
  try {
    file = (await file.exists()) ? file : await file.create();
    file = await file.writeAsBytes(imgBytes); //u good?
    debugPrint('saved ${file}');
    return file;
  } catch (e) {
    debugPrint("!!! failed to store image: " + e.toString());
    return null;
  }
}

Future<Image?> readImage(String name) async {
  final file = (await _localFile(name));
  if (file.existsSync() && file.lengthSync() > 5)
    throw Exception("file ${file} doesnt exist");
  //TODO: was wenn keine datei da lesbar ist? -> return null
  // das ist wichtig damit der placeholder statt einem "image corrupt" dargestellt wird
  return Image.file(await _localFile(name));
}

deleteAll() async => Directory(await _localPath).delete();
