import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:tuple/tuple.dart';
import 'backend/offlineProvider.dart' as OP;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

part 'options.g.dart';

String other = 'other';

@JsonSerializable()
class Options {
  //
  var canBeOffline = true;
  var forceOffline = false;
  //
  var useMobileNetworkForUpload = false;
  var useMobileNetworkForDownload = true;
  //

  var no_image_placeholder_name = "no_default_picture_yet";

  var useSystemTheme = false;

  // @JsonKey(ignore: true)//is a getter anyway
  Map<String, Tuple2<bool Function(), void Function(bool)>> setteableBools(
          BuildContext context) =>
      {
        AppLocalizations.of(context)!.option_canbeoffline:
            Tuple2(() => canBeOffline, (bool value) => canBeOffline = value),
        if (canBeOffline)
          AppLocalizations.of(context)!.option_forceOffline:
              Tuple2(() => forceOffline, (bool value) => forceOffline = value),
        AppLocalizations.of(context)!.option_usemobilenetworkforupload:
            Tuple2(() => useMobileNetworkForUpload, (bool value) {
          useMobileNetworkForUpload = value;
          if (value) useMobileNetworkForDownload = true;
        }),
        AppLocalizations.of(context)!.option_usemobilenetworkfordownload:
            Tuple2(() => useMobileNetworkForDownload, (bool value) {
          useMobileNetworkForDownload = value;
          if (!value) useMobileNetworkForUpload = false;
        }),
        AppLocalizations.of(context)!.option_usesystemtheme: Tuple2(
            () => useSystemTheme, (bool value) => useSystemTheme = value),
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
