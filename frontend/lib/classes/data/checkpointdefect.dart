// ignore_for_file: non_constant_identifier_names

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/helpers/toast.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:provider/provider.dart';

part 'checkpointdefect.g.dart';

@JsonSerializable()
class CheckPointDefect extends Data
    with WithLangText, WithImgHashes, WithAuthor, WithOffline {
  static const pjNr_key = 'PjNr';
  @JsonKey(name: pjNr_key)
  int pjNr;
  static const bauleitung_key = 'Bauleitung';
  @JsonKey(name: bauleitung_key)
  String? bauleitung;
  static const kurzText_key = 'KurzText';
  @JsonKey(name: kurzText_key)
  String? kurzText;
  static const langText_key = 'LangText';
  @JsonKey(name: langText_key)
  String? langText;
  static const erDate_key = 'ErDat';
  @JsonKey(name: erDate_key)
  DateTime? erDate;
  static const eventID_key = 'EventID';
  @JsonKey(name: eventID_key)
  int? eventID;
  static const ereArt_key = 'EREArt';
  @JsonKey(name: ereArt_key)
  int? ereArt;
  static const E1_key = 'E1';
  @JsonKey(name: E1_key)
  int category_index;
  static const E2_key = 'E2';
  @JsonKey(name: E2_key)
  int check_index;
  static const E3_key = 'E3';
  @JsonKey(name: E3_key)
  int index;

  static const height_json_key = "Zusatz_Info";
  @JsonKey(name: height_json_key)
  String? height;

  static const author_key = 'Autor';
  @JsonKey(name: author_key)
  String? author;

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
      _title ??
      kurzText ??
      langText ??
      '$pjNr: Kategorie $category_index, Prüfpunkt $check_index, Mangel $index';

  // void set title(String t) {
  //   _title = t;
  // }

  String? _title;

  @override
  String? get subtitle =>
      height != null ? 'Ort: $height' : null; //'kein Ort spezifiziert';

  @override
  List<Widget> extras({BuildContext? context}) => [
        chipd(ereArt)?.toChip ?? Container(),
        editButton(context: context),
      ];

  Widget editButton({BuildContext? context}) => IconButton(
        // padding: EdgeInsets.zero,
        icon: Icon(Icons.edit),
        onPressed: () async {
          if (context == null) {
            debugPrint("no context from wich we could alert");
            return;
          }
          return showDialog(
            barrierColor: Colors.black54,
            context: context,
            // barrierDismissible: false, // user must tap button!
            barrierDismissible: true,
            builder: (BuildContext innerContext) {
              return AlertDialog(
                title: Text('Mangel bearbeiten'),
                content: CheckPointDefectsModel.adder(
                    parent: Provider.of<CheckPointDefectsModel>(context)
                        .currentData,
                    currentDefect: this,
                    onCancel: () => Navigator.of(context).pop(),
                    onDone: (data) {
                      Provider.of<CheckPointDefectsModel>(context,
                              listen: false)
                          .update(data);
                      // Navigator.of(context).pop();
                    }),
              );
            },
          );
        },
      );

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
    } catch (e) {
      debugPrint("error while parsing CheckPointDefect: $e");
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => _$CheckPointDefectToJson(this);

  @override
  Map<String, dynamic> toSmallJson() => {
        'PjNr': pjNr,
        'E1': category_index,
        'E2': check_index,
        'E3': index,
        'local_id': id
      };
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
