import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';

class InspectionLocation implements Data {
  // TODO: which of them are non-null? // ASKTHIS
  final int pjNr;
  final String pjName;
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
      required this.pjName,
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
}