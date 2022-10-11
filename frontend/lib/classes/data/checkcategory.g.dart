// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkcategory.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckCategory _$CheckCategoryFromJson(Map<String, dynamic> json) =>
    CheckCategory(
      pjNr: json['PjNr'] as int,
      bauleitung: json['Bauleitung'] as String?,
      kurzText: json['KurzText'] as String?,
      langText: json['LangText'] as String?,
      erDate: json['ErDat'] == null
          ? null
          : DateTime.parse(json['ErDat'] as String),
      eventID: json['EventID'] as int?,
      ereArt: json['EREArt'] as int?,
      index: json['E1'] as int,
      e2: json['E2'] as int?,
      e3: json['E3'] as int?,
    )
      ..forceOffline_nullable = json['offline'] as bool?
      ..id = json['local_id'] as String?
      ..author = json['Autor'] as String?
      ..mainhash = json['Mainhash'] as String?
      ..imagehashes =
          (json['images'] as List<dynamic>?)?.map((e) => e as String).toList();

Map<String, dynamic> _$CheckCategoryToJson(CheckCategory instance) =>
    <String, dynamic>{
      'offline': instance.forceOffline_nullable,
      'local_id': instance.id,
      'PjNr': instance.pjNr,
      'Bauleitung': instance.bauleitung,
      'KurzText': instance.kurzText,
      'LangText': instance.langText,
      'ErDat': instance.erDate?.toIso8601String(),
      'EventID': instance.eventID,
      'EREArt': instance.ereArt,
      'E1': instance.index,
      'E2': instance.e2,
      'E3': instance.e3,
      'Autor': instance.author,
      'images': instance.imagehashes,
    };
