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
  ..compactDownload = json['compactDownload'] as bool
  ..no_image_placeholder_name = json['no_image_placeholder_name'] as String
  ..useSystemTheme = json['useSystemTheme'] as bool;

Map<String, dynamic> _$OptionsToJson(Options instance) => <String, dynamic>{
      'canBeOffline': instance.canBeOffline,
      'forceOffline': instance.forceOffline,
      'useMobileNetworkForUpload': instance.useMobileNetworkForUpload,
      'useMobileNetworkForDownload': instance.useMobileNetworkForDownload,
      'compactDownload': instance.compactDownload,
      'no_image_placeholder_name': instance.no_image_placeholder_name,
      'useSystemTheme': instance.useSystemTheme,
    };
