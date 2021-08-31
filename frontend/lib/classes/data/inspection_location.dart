import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

/// stores all the data needed for a specific location in a type-safe way
class InspectionLocation implements Data {
  final int pjNr;
  final String? pjName;
  final String? pjInfo;
  final String? bauleitung;
  final int stONr;
  final String? strasse;
  final String? plz;
  final String? ort;
  final Image?
      defaultpicture; //is a link (Link varchar + LinkOrdner varchar) first needs to be resolved by api.dart

  InspectionLocation(
      {this.bauleitung,
      this.defaultpicture,
      this.ort,
      this.pjInfo,
      this.pjName,
      required this.pjNr,
      this.plz,
      required this.stONr,
      this.strasse});

  @override
  String toString() {
    return 'Ins $pjNr: $pjName';
  }

  String toSubString() {
    return '${bauleitung ?? ''}';
  }

  @override
  String get title => toString();

  static InspectionLocation? fromMap(Map<String, dynamic> map) {
    debugPrint(map.toString());
    try {
      return InspectionLocation(
        pjName: map['PjName'],
        pjNr: map['PjNr'],
        stONr: map['StONr'],
        bauleitung: map['Bauleitung'],
        pjInfo: map['PjInfo'],
        strasse: map['Straße'],
        plz: map['PLZ'],
        ort: map['Ort'],
      );
    } catch (e) {
      return null;
    }
  }
}
