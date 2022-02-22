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

//XXX: ist das redundand mit den latLng?
  @JsonKey(name: "X")
  String? x;
  @JsonKey(name: "Y")
  String? y;

  LatLng? get coords =>
      _toplevelhelperLatLng_fromJson({'lat': x, 'lng': y}) ?? fallback_coords;

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
  Stream<ImageData?> mainImage = Stream.value(null);
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
  var coords = latlng.toJson()['coordinates'];
  return {'lat': coords[0], 'lng': coords[1]};
}

LatLng? _toplevelhelperLatLng_fromJson(Map<String, dynamic> map) {
  try {
    return LatLng.fromJson({
      'coordinates': [map['lat'], map['lng']]
    });
  } catch (e) {
    return null;
  }
}
