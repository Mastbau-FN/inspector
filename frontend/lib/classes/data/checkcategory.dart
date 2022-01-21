import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';

part 'checkcategory.g.dart';

@JsonSerializable()
class CheckCategory extends Data with WithLangText, WithImgHashes, WithAuthor {
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
  int index;
  @JsonKey(name: 'E2')
  int? e2;
  @JsonKey(name: 'E3')
  int? e3;

  @JsonKey(name: 'Autor')
  String? author;

  @JsonKey(name: 'images')
  List<String>? imagehashes; //should not be used
  @JsonKey(ignore: true)
  List<Future<ImageData?>>? image_streams;
  @JsonKey(ignore: true)
  Future<ImageData?> mainImage = Future.value(null);
  @JsonKey(ignore: true)
  Future<ImageData?> previewImage = Future.value(null);

  CheckCategory(
      {required this.pjNr,
      this.bauleitung,
      this.kurzText,
      this.langText,
      this.erDate,
      this.eventID,
      this.ereArt,
      required this.index,
      this.e2,
      this.e3});

  @override
  String get title => kurzText ?? langText ?? '$pjNr: Kategorie $index';

  static CheckCategory? fromJson(Map<String, dynamic> json) {
    try {
      return _$CheckCategoryFromJson(json);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Map<String, dynamic> toJson() => _$CheckCategoryToJson(this);

  @override
  Map<String, dynamic> toSmallJson() => {'PjNr': pjNr, 'E1': index};
}
