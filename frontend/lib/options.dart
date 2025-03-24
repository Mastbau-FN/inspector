import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

import 'backend/offlineProvider.dart' as OP;
import 'package:MBG_Inspektionen/l10n/locales.dart';

part 'options.g.dart';

String other = 'other';

const omitDetailsInLevel2and3 = true;

@JsonSerializable()
class Options {
  //
  var canBeOffline = true;
  var forceOffline = false;
  //
  var useMobileNetworkForUpload = false;
  var useMobileNetworkForDownload = true;
  //

  bool get preloadFullImagesOnManualDownload => !compactDownload;
  bool compactDownload = false;

  var no_image_placeholder_name = "no_default_picture_yet";

  var useSystemTheme = false;

  bool _debugMode = false;
  bool _backupBeforeSync = true;

  bool get debugMode => _debugMode;
  set debugMode(bool value) => _debugMode = value;

  bool get backupBeforeSync => _backupBeforeSync;
  set backupBeforeSync(bool value) => _backupBeforeSync = value;

  // @JsonKey(ignore: true)//is a getter anyway
  Map<String, (bool Function(), void Function(bool))> setteableBools() => {
        S.current!.option_canbeoffline: (
          () => canBeOffline,
          (bool value) => canBeOffline = value
        ),
        if (canBeOffline)
          S.current!.option_forceOffline: (
            () => forceOffline,
            (bool value) => forceOffline = value
          ),
        S.current!.option_usemobilenetworkforupload: (
          () => useMobileNetworkForUpload,
          (bool value) {
            useMobileNetworkForUpload = value;
            if (value) useMobileNetworkForDownload = true;
          }
        ),
        S.current!.option_usemobilenetworkfordownload: (
          () => useMobileNetworkForDownload,
          (bool value) {
            useMobileNetworkForDownload = value;
            if (!value) useMobileNetworkForUpload = false;
          }
        ),
        S.current!.option_usesystemtheme: (
          () => useSystemTheme,
          (bool value) => useSystemTheme = value
        ),
        S.current!.option_compactDownload: (
          () => compactDownload,
          (bool value) {
            compactDownload = value;
          }
        ),
        'debugMode': (() => _debugMode, (bool v) => _debugMode = v),
        'backupBeforeSync': (
          () => _backupBeforeSync,
          (bool v) => _backupBeforeSync = v
        ),
      };

  Map<String, dynamic> toJson() {
    return {
      'useSystemTheme': useSystemTheme,
      'debugMode': _debugMode,
      'backupBeforeSync': _backupBeforeSync,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    useSystemTheme = json['useSystemTheme'] ?? false;
    _debugMode = json['debugMode'] ?? false;
    _backupBeforeSync = json['backupBeforeSync'] ?? true;
  }

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
