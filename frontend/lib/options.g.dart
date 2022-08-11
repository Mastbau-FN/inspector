// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Options _$OptionsFromJson(Map<String, dynamic> json) => Options()
  ..canBeOffline = json['canBeOffline'] as bool
  ..forceOffline = json['forceOffline'] as bool
  ..useMobileNetworkForUpload = json['useMobileNetworkForUpload'] as bool
  ..useMobileNetworkForDownload = json['useMobileNetworkForDownload'] as bool
  ..preferRemote = json['preferRemote'] as bool
  ..mergeOnline = json['mergeOnline'] as bool
  ..mergeOnlineEvenInCached = json['mergeOnlineEvenInCached'] as bool
  ..infinitelyreloadPictures = json['infinitelyreloadPictures'] as bool
  ..reloadTries = json['reloadTries'] as int
  ..no_image_placeholder_name = json['no_image_placeholder_name'] as String
  ..showDoggo = json['showDoggo'] as bool
  ..debugAllResponses = json['debugAllResponses'] as bool
  ..debugLocalMirror = json['debugLocalMirror'] as bool
  ..debugImages = json['debugImages'] as bool;

Map<String, dynamic> _$OptionsToJson(Options instance) => <String, dynamic>{
      'canBeOffline': instance.canBeOffline,
      'forceOffline': instance.forceOffline,
      'useMobileNetworkForUpload': instance.useMobileNetworkForUpload,
      'useMobileNetworkForDownload': instance.useMobileNetworkForDownload,
      'preferRemote': instance.preferRemote,
      'mergeOnline': instance.mergeOnline,
      'mergeOnlineEvenInCached': instance.mergeOnlineEvenInCached,
      'infinitelyreloadPictures': instance.infinitelyreloadPictures,
      'reloadTries': instance.reloadTries,
      'no_image_placeholder_name': instance.no_image_placeholder_name,
      'showDoggo': instance.showDoggo,
      'debugAllResponses': instance.debugAllResponses,
      'debugLocalMirror': instance.debugLocalMirror,
      'debugImages': instance.debugImages,
    };
