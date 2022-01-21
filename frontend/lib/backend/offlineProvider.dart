import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

Future<String> get _localPath async =>
    (await getApplicationDocumentsDirectory()).path;

Future<File> _localFile(String name) async =>
    File('${await _localPath}/${name}');

Future<XFile?> storeImage(Uint8List imgBytes, String name) async {
  final file = await _localFile(name);

  // Write the file
  try {
    await file.create();
    await file.writeAsBytes(imgBytes); //warum gehst du nicht :(
    //return XFile(file.path);
  } catch (e) {
    return null;
  }
}

Future<Image> readImage(String name) async =>
    Image.file(await _localFile(name));
