// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'requestData.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RequestData _$RequestDataFromJson(Map<String, dynamic> json) => RequestData(
      json['route'] as String,
      json: json['json'] as Map<String, dynamic>?,
      multipartFileNames: (json['multipartFileNames'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      timeout: json['timeout'] == null
          ? null
          : Duration(microseconds: json['timeout'] as int),
      returnsBinary: json['returnsBinary'] as bool? ?? false,
      logIfFailed: json['logIfFailed'] as bool?,
    );

Map<String, dynamic> _$RequestDataToJson(RequestData instance) =>
    <String, dynamic>{
      'route': instance.route,
      'json': instance.json,
      'multipartFileNames': instance.multipartFileNames,
      'timeout': instance.timeout?.inMicroseconds,
      'returnsBinary': instance.returnsBinary,
    };
