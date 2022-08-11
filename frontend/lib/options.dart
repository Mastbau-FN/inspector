import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tuple/tuple.dart';
import 'backend/offlineProvider.dart' as OP;

part 'options.g.dart';

String other = 'other';

@JsonSerializable()
class Options {
  var canBeOffline = false;
  var canUseMobileNetworkIfPossible = true;
  var preferRemoteImages = false;
  var debugAllResponses = false;
  var debugLocalMirror = true;
  var debugImages = false;
  var infinitelyreloadPictures = true;
  var reloadTries = 5;
  var showDoggo = false;
  var no_image_placeholder_name = "no_default_picture_yet";
  var mergeLoadedDataIntoOnlineData = true; //XXX: make false to solve #212
  var mergeLoadedDataIntoOnlineDataEvenInCachedParent = false;
  var useMobileNetworkForUpload = false;
  var useMobileNetworkForDownload = true;

  @JsonKey(ignore: true)
  Map<String, Tuple2<bool Function(), void Function(bool)>> setteableBools() =>
      {
        'canBeOffline':
            Tuple2(() => canBeOffline, (bool value) => canBeOffline = value),
        'canUseMobileNetworkIfPossible': Tuple2(
            () => canUseMobileNetworkIfPossible,
            (bool value) => canUseMobileNetworkIfPossible = value),
        'preferRemoteImages': Tuple2(() => preferRemoteImages,
            (bool value) => preferRemoteImages = value),
        'debugAllResponses': Tuple2(
            () => debugAllResponses, (bool value) => debugAllResponses = value),
        'debugLocalMirror': Tuple2(
            () => debugLocalMirror, (bool value) => debugLocalMirror = value),
        'debugImages':
            Tuple2(() => debugImages, (bool value) => debugImages = value),
        'infinitelyreloadPictures': Tuple2(() => infinitelyreloadPictures,
            (bool value) => infinitelyreloadPictures = value),
        'showDoggo': Tuple2(() => showDoggo, (bool value) => showDoggo = value),
        'mergeLoadedDataIntoOnlineData': Tuple2(
            () => mergeLoadedDataIntoOnlineData,
            (bool value) => mergeLoadedDataIntoOnlineData = value),
        'mergeLoadedDataIntoOnlineDataEvenInCachedParent': Tuple2(
            () => mergeLoadedDataIntoOnlineDataEvenInCachedParent,
            (bool value) =>
                mergeLoadedDataIntoOnlineDataEvenInCachedParent = value),
        'useMobileNetworkForUpload': Tuple2(() => useMobileNetworkForUpload,
            (bool value) => useMobileNetworkForUpload = value),
        'useMobileNetworkForDownload': Tuple2(() => useMobileNetworkForDownload,
            (bool value) => useMobileNetworkForDownload = value),
      };

  static final String _id = '__options__';
  static Options _instance = Options._internal();
  factory Options() => _instance;

  Options._internal() {
    // init
    OP.db.collection(other).doc(_id).get().then((value) {
      try {
        _instance = _$OptionsFromJson(value!);
      } catch (e) {}
    });
  }

  Future store() => OP.db.collection(other).doc(_id).set(_$OptionsToJson(this));
}

class Design {
  static var mainBorderRadius = BorderRadius.circular(20.0);
}
