// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Options _$OptionsFromJson(Map<String, dynamic> json) => Options()
  ..canBeOffline = json['canBeOffline'] as bool
  ..canUseMobileNetworkIfPossible =
      json['canUseMobileNetworkIfPossible'] as bool
  ..preferRemoteImages = json['preferRemoteImages'] as bool
  ..debugAllResponses = json['debugAllResponses'] as bool
  ..debugLocalMirror = json['debugLocalMirror'] as bool
  ..debugImages = json['debugImages'] as bool
  ..infinitelyreloadPictures = json['infinitelyreloadPictures'] as bool
  ..reloadTries = json['reloadTries'] as int
  ..showDoggo = json['showDoggo'] as bool
  ..no_image_placeholder_name = json['no_image_placeholder_name'] as String;

Map<String, dynamic> _$OptionsToJson(Options instance) => <String, dynamic>{
      'canBeOffline': instance.canBeOffline,
      'canUseMobileNetworkIfPossible': instance.canUseMobileNetworkIfPossible,
      'preferRemoteImages': instance.preferRemoteImages,
      'debugAllResponses': instance.debugAllResponses,
      'debugLocalMirror': instance.debugLocalMirror,
      'debugImages': instance.debugImages,
      'infinitelyreloadPictures': instance.infinitelyreloadPictures,
      'reloadTries': instance.reloadTries,
      'showDoggo': instance.showDoggo,
      'no_image_placeholder_name': instance.no_image_placeholder_name,
    };
