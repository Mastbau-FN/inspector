import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/dropdown/dropdownModel.dart';
import 'package:json_annotation/json_annotation.dart';

part 'checkpoint.g.dart';

@JsonSerializable()
class CheckPoint implements Data {
  @JsonKey(name: 'PjNr')
  int pjNr;
  @JsonKey(name: 'Bauleitung')
  String? bauleitung;
  @JsonKey(name: 'KurzText')
  String? kurzText;
  @JsonKey(name: 'LangText')
  String? langText;
  @JsonKey(name: 'ErDat')
  DateTime? erDate;
  @JsonKey(name: 'EventID')
  int? eventID;
  @JsonKey(name: 'EREArt')
  int? ereArt;
  @JsonKey(name: 'E1')
  int category_index;
  @JsonKey(name: 'E2')
  int index;
  @JsonKey(name: 'E3')
  int? e3;

  @JsonKey(name: 'images')
  List<String> imagehashes = []; //should not be used
  @JsonKey(ignore: true)
  List<Image?> images = [];

  CheckPoint(
      {required this.pjNr,
      this.bauleitung,
      this.kurzText,
      this.langText,
      ////this.link,
      ////this.linkOrdner,
      this.erDate,
      this.eventID,
      this.ereArt,
      required this.category_index,
      required this.index,
      this.e3});

  @override
  String get title =>
      kurzText ??
      langText ??
      '$pjNr: Kategorie $category_index, Prüfpunkt $index';

  static CheckPoint? fromJson(Map<String, dynamic> json) {
    try {
      return _$CheckPointFromJson(json);
    } catch (e) {}
  }

  @override
  Map<String, dynamic> toJson() => _$CheckPointToJson(this);

  @override
  Map<String, dynamic> toSmallJson() =>
      {'PjNr': pjNr, 'E1': category_index, 'E2': index};
}
