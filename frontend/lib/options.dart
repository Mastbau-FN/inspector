import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tuple/tuple.dart';
import 'backend/offlineProvider.dart' as OP;
import 'generated/l10n.dart';

part 'options.g.dart';

String other = 'other';

@JsonSerializable()
class Options {
  //
  var canBeOffline = true;
  var forceOffline = true;
  //
  var useMobileNetworkForUpload = false;
  var useMobileNetworkForDownload = true;
  //
  var preferRemote = false;
  //
  var mergeOnline = true; //XXX: make false to solve #212
  var mergeOnlineEvenInCached = false;
  //
  var infinitelyreloadPictures = true;
  var reloadTries = 5;
  var no_image_placeholder_name = "no_default_picture_yet";
  //

  var showDoggo = false;
  var debugAllResponses = false;
  var debugLocalMirror = true;
  var debugImages = false;

  @JsonKey(ignore: true)
  Map<String, Tuple2<bool Function(), void Function(bool)>> setteableBools() =>
      {
        S.current.option_canbeoffline:
            Tuple2(() => canBeOffline, (bool value) => canBeOffline = value),
        if (canBeOffline)
          S.current.option_forceOffline:
              Tuple2(() => forceOffline, (bool value) => forceOffline = value),
        S.current.option_usemobilenetworkforupload: Tuple2(
            () => useMobileNetworkForUpload,
            (bool value) => useMobileNetworkForUpload = value),
        S.current.option_usemobilenetworkfordownload: Tuple2(
            () => useMobileNetworkForDownload,
            (bool value) => useMobileNetworkForDownload = value),
        S.current.option_mergeloadeddataintoonlinedata:
            Tuple2(() => mergeOnline, (bool value) => mergeOnline = value),
        S.current.option_mergeloadeddataintoonlinedataevenincachedparent:
            Tuple2(() => mergeOnlineEvenInCached,
                (bool value) => mergeOnlineEvenInCached = value),
        S.current.option_preferremoteimages:
            Tuple2(() => preferRemote, (bool value) => preferRemote = value),
        S.current.option_infinitelyreloadpictures: Tuple2(
            () => infinitelyreloadPictures,
            (bool value) => infinitelyreloadPictures = value),
        S.current.option_showdoggo:
            Tuple2(() => showDoggo, (bool value) => showDoggo = value),
        S.current.option_debugallresponses: Tuple2(
            () => debugAllResponses, (bool value) => debugAllResponses = value),
        S.current.option_debuglocalmirror: Tuple2(
            () => debugLocalMirror, (bool value) => debugLocalMirror = value),
        S.current.option_debugimages:
            Tuple2(() => debugImages, (bool value) => debugImages = value),
      };

  static final String _id = '__options__';
  static Options _instance = Options._internal();
  factory Options() => _instance;

  Options._internal() {
    // init
    load();
  }

  Future load() => OP.db.collection(other).doc(_id).get().then((value) {
        try {
          _instance = _$OptionsFromJson(value!);
        } catch (e) {}
      });

  Future store() => OP.db.collection(other).doc(_id).set(_$OptionsToJson(this));
}

class Design {
  static var mainBorderRadius = BorderRadius.circular(20.0);
}
