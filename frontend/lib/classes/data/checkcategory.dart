import 'package:MBG_Inspektionen/classes/imageData.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:provider/provider.dart';

import '../../backend/api.dart';

part 'checkcategory.g.dart';

@JsonSerializable()
class CheckCategory extends Data
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
  List<Future<ImageData?>>? imageFutures;
  // @JsonKey(ignore: true)
  // Future<ImageData?>? mainImage;
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
                title: Text('Kategorie bearbeiten'),
                content: CategoryModel.adder(
                    parent: Provider.of<CategoryModel>(context).currentData,
                    currentCategory: this,
                    onCancel: () => Navigator.of(context).pop(),
                    onDone: (data) {
                      Provider.of<CategoryModel>(context, listen: false)
                          .update(data);
                      // Navigator.of(context).pop();
                    }),
              );
            },
          );
        },
      );

  @override
  String get title => kurzText ?? langText ?? '$pjNr: Kategorie $index';

  static CheckCategory? fromJson(Map<String, dynamic> json) {
    try {
      return _$CheckCategoryFromJson(json);
    } catch (e) {
      debugPrint(e.toString());
    }
    return null;
  }

  @override
  Map<String, dynamic> toJson() => _$CheckCategoryToJson(this);

  @override
  Map<String, dynamic> toSmallJson() =>
      {'PjNr': pjNr, 'E1': index, 'local_id': id};
}
