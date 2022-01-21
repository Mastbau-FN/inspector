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
  var file = await _localFile(name);

  // Write the file
  try {
    (await file.exists()) ? file : await file.create();
    await file.writeAsBytes(imgBytes); //warum gehst du nicht :(
    return XFile(file.path);
  } catch (e) {
    return null;
  }
}

Future<Image> readImage(String name) async => Image.network(
    'https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Bild_21_-_Verbot_der_%C3%9Cberschreitung_bestimmter_Fahrgeschwindigkeiten_-_30_km%2C_StVO_1953.svg/1024px-Bild_21_-_Verbot_der_%C3%9Cberschreitung_bestimmter_Fahrgeschwindigkeiten_-_30_km%2C_StVO_1953.svg.png');
    // Image.file(await _localFile(name));
