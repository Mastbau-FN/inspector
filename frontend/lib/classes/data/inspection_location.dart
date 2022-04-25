import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';
import "package:latlong2/latlong.dart";

part 'inspection_location.g.dart';

/// stores all the data needed for a specific location in a type-safe way

@JsonSerializable()
class InspectionLocation extends Data with WithImgHashes, WithLangText {
  @JsonKey(name: 'local_id')
  String? id;
  @JsonKey(name: 'PjNr')
  final int pjNr;
  @JsonKey(name: 'PjName')
  final String? pjName;
  @JsonKey(name: 'PjInfo')
  final String? pjInfo;
  @JsonKey(name: 'Bauleitung')
  final String? bauleitung;
  @JsonKey(name: 'StONr')
  final int stONr;
  @JsonKey(name: 'Straße')
  final String? strasse;
  @JsonKey(name: 'PLZ')
  final String? plz;
  @JsonKey(name: 'Ort')
  final String? ort;

  @JsonKey(name: "Eigentuemer")
  String? eigentuemer;
  @JsonKey(name: "Bauwerkhoehe")
  int? bauwerkhoehe;
  @JsonKey(name: "Baujahr")
  int? baujahr;
  @JsonKey(name: "Ansprechpartner")
  String? ansprechpartner;
  @JsonKey(name: "Steigwegtyp")
  String? steigwegtyp;
  @JsonKey(name: "Schluessel")
  bool? needs_schluessel;
  @JsonKey(name: "Abschaltungen")
  String? abschaltungen;
  @JsonKey(name: "Steckdosen")
  bool? has_steckdosen;
  @JsonKey(name: "WC")
  bool? has_wc;
  @JsonKey(name: "Lagerraeume")
  bool? has_lagerraeume;
  @JsonKey(name: "Steigschutzschluessel")
  String? steigschutzschluessel;

  @JsonKey(name: "ASP_required")
  bool? asp_required;
  @JsonKey(name: "Steckdosen_description")
  String? steckdosen_description;
  @JsonKey(name: "Schlüssel_description")
  String? schlussel_description;

  //Wetter
  @JsonKey(name: "Temperatur")
  String? temp;
  @JsonKey(name: "Wetter")
  String? weather;
  @JsonKey(name: "Wind")
  String? wind;
  @JsonKey(name: "Windrichtung")
  String? wind_direction;

//XXX: ist das redundand mit den latLng?
  @JsonKey(name: "X")
  String? x;
  @JsonKey(name: "Y")
  String? y;

  LatLng? get coords => y != null && x != null
      ? LatLng(double.parse(y!.replaceAll(',', '.')),
          double.parse(x!.replaceAll(',', '.')))
      : fallback_coords;

  @JsonKey(
    name: 'latLng',
    fromJson: _toplevelhelperLatLng_fromJson,
    toJson: _toplevelhelperLatLng_toJson,
  )
  final LatLng? fallback_coords;

  @JsonKey(name: 'images')
  List<String>? imagehashes; //should not be used
  @JsonKey(ignore: true)
  List<Stream<ImageData?>>? image_streams;
  @JsonKey(ignore: true)
  Stream<ImageData?>? mainImage;
  @JsonKey(ignore: true)
  Stream<ImageData?> previewImage = Stream.value(null);

  InspectionLocation({
    this.bauleitung,
    ////this.defaultpicture,
    this.ort,
    this.pjInfo,
    this.pjName,
    required this.pjNr,
    this.plz,
    required this.stONr,
    this.strasse,
    this.fallback_coords,
  });

  @override
  String toString() {
    return pjName ?? 'Inspektion $pjNr';
  }

  String toSubString() {
    return '${bauleitung ?? ''}';
  }

  @override
  String get title => toString();

  static InspectionLocation? fromJson(Map<String, dynamic> json) {
    try {
      return _$InspectionLocationFromJson(json);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Map<String, dynamic> toJson() => _$InspectionLocationToJson(this);

  @override
  Map<String, dynamic> toSmallJson() => {'PjNr': pjNr};
}

Map<String, dynamic> _toplevelhelperLatLng_toJson(LatLng? latlng) {
  if (latlng == null) return {};
  return {'lat': latlng.latitude, 'lng': latlng.longitude};
}

LatLng? _toplevelhelperLatLng_fromJson(Map<String, dynamic> map) {
  try {
    return LatLng(map['lat'], map['lng']);
  } catch (e) {
    return null;
  }
}
