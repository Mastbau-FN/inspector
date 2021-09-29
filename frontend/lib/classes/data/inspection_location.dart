import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inspection_location.g.dart';

/// stores all the data needed for a specific location in a type-safe way

@JsonSerializable()
class InspectionLocation implements Data {
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

  @JsonKey(name: 'images')
  List<String>? imagehashes; //should not be used
  @JsonKey(ignore: true)
  List<Image?>? images;

  InspectionLocation(
      {this.bauleitung,
      ////this.defaultpicture,
      this.ort,
      this.pjInfo,
      this.pjName,
      required this.pjNr,
      this.plz,
      required this.stONr,
      this.strasse});

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
    } catch (e) {}
  }

  Map<String, dynamic> toJson() => _$InspectionLocationToJson(this);

  @override
  Map<String, dynamic> toSmallJson() => {'PjNr': pjNr};
}
