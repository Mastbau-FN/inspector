// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkpoint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CheckPoint _$CheckPointFromJson(Map<String, dynamic> json) {
  return CheckPoint(
    pjNr: json['PjNr'] as int,
    bauleitung: json['Bauleitung'] as String?,
    kurzText: json['KurzText'] as String?,
    langText: json['LangText'] as String?,
    erDate:
        json['ErDat'] == null ? null : DateTime.parse(json['ErDat'] as String),
    eventID: json['EventID'] as int?,
    ereArt: json['EREArt'] as int?,
    category_index: json['E1'] as int,
    index: json['E2'] as int,
    e3: json['E3'] as int?,
  )..imagehashes =
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList();
}

Map<String, dynamic> _$CheckPointToJson(CheckPoint instance) =>
    <String, dynamic>{
      'PjNr': instance.pjNr,
      'Bauleitung': instance.bauleitung,
      'KurzText': instance.kurzText,
      'LangText': instance.langText,
      'ErDat': instance.erDate?.toIso8601String(),
      'EventID': instance.eventID,
      'EREArt': instance.ereArt,
      'E1': instance.category_index,
      'E2': instance.index,
      'E3': instance.e3,
      'images': instance.imagehashes,
    };
