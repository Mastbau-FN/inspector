// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InspectionLocation _$InspectionLocationFromJson(Map<String, dynamic> json) {
  debugPrint(json.toString());
  return InspectionLocation(
    bauleitung: json['Bauleitung'] as String?,
    ort: json['Ort'] as String?,
    pjInfo: json['PjInfo'] as String?,
    pjName: json['PjName'] as String?,
    pjNr: json['PjNr'] as int,
    plz: json['PLZ'] as String?,
    stONr: json['StONr'] as int,
    strasse: json['Straße'] as String?,
    coords: json['latLng'] == null
        ? null
        : LatLng.fromJson(json['latLng'] as Map<String, dynamic>),
  )..imagehashes =
      (json['images'] as List<dynamic>?)?.map((e) => e as String).toList();
}

Map<String, dynamic> _$InspectionLocationToJson(InspectionLocation instance) =>
    <String, dynamic>{
      'PjNr': instance.pjNr,
      'PjName': instance.pjName,
      'PjInfo': instance.pjInfo,
      'Bauleitung': instance.bauleitung,
      'StONr': instance.stONr,
      'Straße': instance.strasse,
      'PLZ': instance.plz,
      'Ort': instance.ort,
      'latLng': instance.coords,
      'images': instance.imagehashes,
    };
