// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inspection_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InspectionLocation _$InspectionLocationFromJson(Map<String, dynamic> json) =>
    InspectionLocation(
      bauleitung: json['Bauleitung'] as String?,
      ort: json['Ort'] as String?,
      pjInfo: json['PjInfo'] as String?,
      pjName: json['PjName'] as String?,
      pjNr: json['PjNr'] as int,
      plz: json['PLZ'] as String?,
      stONr: json['StONr'] as int,
      strasse: json['Straße'] as String?,
      fallback_coords: _toplevelhelperLatLng_fromJson(
          json['latLng'] as Map<String, dynamic>),
    )
      ..langText = json['langText'] as String?
      ..id = json['local_id'] as String?
      ..eigentuemer = json['Eigentuemer'] as String?
      ..bauwerkhoehe = json['Bauwerkhoehe'] as int?
      ..baujahr = json['Baujahr'] as int?
      ..ansprechpartner = json['Ansprechpartner'] as String?
      ..steigwegtyp = json['Steigwegtyp'] as String?
      ..needs_schluessel = json['Schluessel'] as bool?
      ..abschaltungen = json['Abschaltungen'] as String?
      ..has_steckdosen = json['Steckdosen'] as bool?
      ..has_wc = json['WC'] as bool?
      ..has_lagerraeume = json['Lagerraeume'] as bool?
      ..steigschutzschluessel = json['Steigschutzschluessel'] as String?
      ..asp_required = json['ASP_required'] as bool?
      ..steckdosen_description = json['Steckdosen_description'] as String?
      ..schlussel_description = json['Schlüssel_description'] as String?
      ..temp = json['Temperatur'] as int?
      ..weather = $enumDecodeNullable(_$WeatherEnumMap, json['Wetter'])
      ..wind_speed = $enumDecodeNullable(_$WindPowerEnumMap, json['Wind'])
      ..wind_direction =
          $enumDecodeNullable(_$WindDirectionEnumMap, json['Windrichtung'])
      ..x = json['X'] as String?
      ..y = json['Y'] as String?
      ..imagehashes =
          (json['images'] as List<dynamic>?)?.map((e) => e as String).toList();

Map<String, dynamic> _$InspectionLocationToJson(InspectionLocation instance) =>
    <String, dynamic>{
      'langText': instance.langText,
      'local_id': instance.id,
      'PjNr': instance.pjNr,
      'PjName': instance.pjName,
      'PjInfo': instance.pjInfo,
      'Bauleitung': instance.bauleitung,
      'StONr': instance.stONr,
      'Straße': instance.strasse,
      'PLZ': instance.plz,
      'Ort': instance.ort,
      'Eigentuemer': instance.eigentuemer,
      'Bauwerkhoehe': instance.bauwerkhoehe,
      'Baujahr': instance.baujahr,
      'Ansprechpartner': instance.ansprechpartner,
      'Steigwegtyp': instance.steigwegtyp,
      'Schluessel': instance.needs_schluessel,
      'Abschaltungen': instance.abschaltungen,
      'Steckdosen': instance.has_steckdosen,
      'WC': instance.has_wc,
      'Lagerraeume': instance.has_lagerraeume,
      'Steigschutzschluessel': instance.steigschutzschluessel,
      'ASP_required': instance.asp_required,
      'Steckdosen_description': instance.steckdosen_description,
      'Schlüssel_description': instance.schlussel_description,
      'Temperatur': instance.temp,
      'Wetter': _$WeatherEnumMap[instance.weather],
      'Wind': _$WindPowerEnumMap[instance.wind_speed],
      'Windrichtung': _$WindDirectionEnumMap[instance.wind_direction],
      'X': instance.x,
      'Y': instance.y,
      'latLng': _toplevelhelperLatLng_toJson(instance.fallback_coords),
      'images': instance.imagehashes,
    };

const _$WeatherEnumMap = {
  Weather.rain: 'Niederschlag',
  Weather.rain_snow: 'Regen',
  Weather.snow: 'Schnee',
  Weather.sun: 'Sonne',
  Weather.sun_sunny: 'Sonnig',
  Weather.clouds: 'Wolken',
  Weather.wind: 'Wind',
  Weather.thunderstorm: 'Gewitter',
  Weather.hail: 'Hagel',
  Weather.fog: 'Nebel',
  Weather.storm: 'Sturm',
};

const _$WindPowerEnumMap = {
  WindPower.none: '0',
  WindPower.light: '1',
  WindPower.medium: '2',
  WindPower.strong: '3',
};

const _$WindDirectionEnumMap = {
  WindDirection.north: 'N',
  WindDirection.north_north_east: 'NNO',
  WindDirection.north_east: 'NO',
  WindDirection.east_north_east: 'ONO',
  WindDirection.east: 'O',
  WindDirection.east_south_east: 'OSO',
  WindDirection.south_east: 'SO',
  WindDirection.south_south_east: 'SSO',
  WindDirection.south: 'S',
  WindDirection.south_south_west: 'SSW',
  WindDirection.south_west: 'SW',
  WindDirection.west_south_west: 'WSW',
  WindDirection.west: 'W',
  WindDirection.west_north_west: 'WNW',
  WindDirection.north_west: 'NW',
  WindDirection.north_north_west: 'NNW',
};
