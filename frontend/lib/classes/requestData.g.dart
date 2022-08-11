// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'requestData.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestData _$RequestDataFromJson(Map<String, dynamic> json) => RequestData(
      json['route'] as String,
      json: json['json'] as Map<String, dynamic>?,
      multipartFiles: json['multipart_files'] == null
          ? const []
          : _multipartFilesFromJson(json['multipart_files'] as List),
      timeout: json['timeout'] == null
          ? null
          : Duration(microseconds: json['timeout'] as int),
      returnsBinary: json['returnsBinary'] as bool? ?? false,
    );

Map<String, dynamic> _$RequestDataToJson(RequestData instance) =>
    <String, dynamic>{
      'route': instance.route,
      'json': instance.json,
      'multipart_files': _multipartFilesToJson(instance.multipartFiles),
      'timeout': instance.timeout?.inMicroseconds,
      'returnsBinary': instance.returnsBinary,
    };
