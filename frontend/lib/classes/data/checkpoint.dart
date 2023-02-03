// ignore_for_file: non_constant_identifier_names

import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:provider/provider.dart';

import '../../backend/api.dart';
import '../../pages/checkpoints.dart';
import '../user.dart';

part 'checkpoint.g.dart';

@JsonSerializable()
class CheckPoint extends Data
    with WithLangText, WithImgHashes, WithAuthor, WithOffline {
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

  @JsonKey(name: 'Autor')
  String? author;

  @JsonKey(name: 'images')
  List<String>? imagehashes; //should not be used
  @JsonKey(ignore: true)
  List<Future<ImageData?>>? imageFutures;
  // @JsonKey(ignore: true)
  // Future<ImageData?>? mainImage;
  @JsonKey(ignore: true)
  Future<ImageData?> previewImage = Future.value(null);

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

  @override
  List<Widget> extras({BuildContext? context}) {
    return [
      FutureBuilder(
        builder: (context, AsyncSnapshot<DisplayUser?> snapshot) {
          if (snapshot.hasData && snapshot.data?.name == author) {
            return editButton(context: context);
          }
          return Container();
        },
        future: API().user,
      )
    ];
  }

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
                title: Text('Punkt bearbeiten'),
                content: CheckPointsModel.adder(
                    parent: Provider.of<CheckPointsModel>(context).currentData,
                    currentCheckpoint: this,
                    onCancel: () => Navigator.of(context).pop(),
                    onDone: (data) {
                      Provider.of<CheckPointsModel>(context, listen: false)
                          .update(data);
                      // Navigator.of(context).pop();
                    }),
              );
            },
          );
        },
      );

  static CheckPoint? fromJson(Map<String, dynamic> json) {
    try {
      return _$CheckPointFromJson(json);
    } catch (e) {}
    return null;
  }

  @override
  Map<String, dynamic> toJson() => _$CheckPointToJson(this);

  @override
  Map<String, dynamic> toSmallJson() =>
      {'PjNr': pjNr, 'E1': category_index, 'E2': index, 'local_id': id};
}
