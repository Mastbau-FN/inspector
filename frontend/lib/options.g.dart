// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'options.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Options _$OptionsFromJson(Map<String, dynamic> json) => Options()
  ..canBeOffline = json['canBeOffline'] as bool
  ..forceOffline = json['forceOffline'] as bool
  ..tryOnlineIfOfflineFailed = json['tryOnlineIfOfflineFailed'] as bool
  ..useMobileNetworkForUpload = json['useMobileNetworkForUpload'] as bool
  ..useMobileNetworkForDownload = json['useMobileNetworkForDownload'] as bool
  ..preferRemoteData = json['preferRemoteData'] as bool
  ..preferRemoteImgs = json['preferRemoteImgs'] as bool
  ..tryOnlineUploadRequestsInCachedMode =
      json['tryOnlineUploadRequestsInCachedMode'] as bool
  ..mergeOnline = json['mergeOnline'] as bool
  ..mergeOnlineEvenInCached = json['mergeOnlineEvenInCached'] as bool
  ..infinitelyreloadPictures = json['infinitelyreloadPictures'] as bool
  ..reloadTries = json['reloadTries'] as int
  ..no_image_placeholder_name = json['no_image_placeholder_name'] as String
  ..showDoggo = json['showDoggo'] as bool
  ..debugAllResponses = json['debugAllResponses'] as bool
  ..debugLocalMirror = json['debugLocalMirror'] as bool
  ..debugImages = json['debugImages'] as bool
  ..useSystemTheme = json['useSystemTheme'] as bool;

Map<String, dynamic> _$OptionsToJson(Options instance) => <String, dynamic>{
      'canBeOffline': instance.canBeOffline,
      'forceOffline': instance.forceOffline,
      'tryOnlineIfOfflineFailed': instance.tryOnlineIfOfflineFailed,
      'useMobileNetworkForUpload': instance.useMobileNetworkForUpload,
      'useMobileNetworkForDownload': instance.useMobileNetworkForDownload,
      'preferRemoteData': instance.preferRemoteData,
      'preferRemoteImgs': instance.preferRemoteImgs,
      'tryOnlineUploadRequestsInCachedMode':
          instance.tryOnlineUploadRequestsInCachedMode,
      'mergeOnline': instance.mergeOnline,
      'mergeOnlineEvenInCached': instance.mergeOnlineEvenInCached,
      'infinitelyreloadPictures': instance.infinitelyreloadPictures,
      'reloadTries': instance.reloadTries,
      'no_image_placeholder_name': instance.no_image_placeholder_name,
      'showDoggo': instance.showDoggo,
      'debugAllResponses': instance.debugAllResponses,
      'debugLocalMirror': instance.debugLocalMirror,
      'debugImages': instance.debugImages,
      'useSystemTheme': instance.useSystemTheme,
    };
