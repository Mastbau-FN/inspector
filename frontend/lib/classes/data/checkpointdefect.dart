import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/image.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';

part 'checkpointdefect.g.dart';

@JsonSerializable()
class CheckPointDefect extends Data
    with WithLangText, WithImgHashes, WithAuthor {
  @JsonKey(name: 'local_id')
  String? id;
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
  int check_index;
  @JsonKey(name: 'E3')
  int index;

  // @JsonKey(name: "Zusatz_info")
  @JsonKey(
      name:
          "height") //der ist es momentan, also dont forget to change it in https://github.com/Mastbau-FN/inspector/blob/6d81894f150484821a3e377bfd89d6f51471f6f0/frontend/lib/pages/checkpointdefects.dart#L111-L112
  String? height;

  @JsonKey(name: 'Autor')
  String? author;

  @JsonKey(name: 'images')
  List<String>? imagehashes; //should not be used
  @JsonKey(ignore: true)
  List<Future<ImageData?>>? image_futures;
  @JsonKey(ignore: true)
  Future<ImageData?>? mainImage;
  @JsonKey(ignore: true)
  Future<ImageData?> previewImage = Future.value(null);

  CheckPointDefect(
      {required this.pjNr,
      this.bauleitung,
      this.kurzText,
      this.langText,
      this.erDate,
      this.eventID,
      this.ereArt,
      required this.category_index,
      required this.check_index,
      required this.index});

  @override
  String get title =>
      kurzText ??
      langText ??
      '$pjNr: Kategorie $category_index, Prüfpunkt $check_index, Mangel $index';

  @override
  String? get subtitle =>
      height != null ? 'Ort: $height' : null; //'kein Ort spezifiziert';

  @override
  Widget? get extra => chipd(ereArt)?.toChip;

  static ChipData? chipd(int? oufness) {
    switch (oufness) {
      case null:
        return null;
      case 5201:
        return ChipData(
          label: "leicht",
          backgroundColor: Colors.green,
        );
      case 5202:
        return ChipData(
          label: "mittel",
          backgroundColor: Colors.orange,
        );
      case 5203:
        return ChipData(
          label: "schwer",
          backgroundColor: Colors.red,
        );
      case 5204:
      default:
        return ChipData(
          label: "ohne",
          backgroundColor: Colors.grey,
        );
    }
  }

  static CheckPointDefect? fromJson(Map<String, dynamic> json) {
    try {
      return _$CheckPointDefectFromJson(json);
    } catch (e) {}
  }

  @override
  Map<String, dynamic> toJson() => _$CheckPointDefectToJson(this);

  @override
  Map<String, dynamic> toSmallJson() =>
      {'PjNr': pjNr, 'E1': category_index, 'E2': check_index, 'E3': index};
}

class ChipData {
  final String? label;
  final Color? backgroundColor;
  const ChipData({this.label, this.backgroundColor});
  Widget get toChip => Chip(
        labelStyle: TextStyle(color: Colors.white),
        label: Text(label ?? ""),
        backgroundColor: backgroundColor,
      );
}
