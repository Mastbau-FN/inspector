import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:inspector/backend/api.dart';
import 'package:inspector/classes/data/checkcategory.dart';
import 'package:inspector/classes/data/checkpoint.dart';
import 'package:inspector/classes/listTileData.dart';
import 'package:inspector/fragments/adder.dart';
import 'package:inspector/pages/checkpointdefectsModel.dart';
import 'package:inspector/pages/dropdown/dropdownModel.dart';

import 'imageView.dart';

class CheckPointsModel extends DropDownModel<CheckPoint> {
  final Backend _b = Backend();
  final CheckCategory currentCategory;

  static const _nextViewTitle = "Defekte";

  CheckPointsModel(this.currentCategory);

  Future<List<CheckPoint>> get all async =>
      _b.getAllCheckPointsForCategory(currentCategory);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.report_problem,
    ),
    MyListTileData(
      title: "Fotos",
      icon: Icons.photo_library,
    ),
    MyListTileData(
      title: "Kommentar",
      icon: Icons.text_snippet,
    ),
  ];

  @override
  String get title => currentCategory.title;

  @override
  void open(
    BuildContext context,
    CheckPoint data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel(CheckPointDefectsModel(data));
          case 'Fotos':
            return ImageView(
              images: data.images,
            );

          default:
            return Text("TODO");
        }
      }),
    );
  }

  @override
  Widget? get floatingActionButton => TransformeableActionbutton(
        expandedHeight: 200,
        expandedChild: (onCancel) => Adder(
          'checkpoint',
          onSet: (json) async {
            Map<String, dynamic> checkpoint = json['checkpoint'];
            checkpoint['PjNr'] = currentCategory.pjNr;
            checkpoint['E1'] = currentCategory.index;
            checkpoint['E2'] = -1;
            await Backend().setNew(CheckPoint.fromJson(checkpoint));
            notifyListeners();
          },
          onCancel: onCancel,
          textfield_list: [
            InputData("KurzText", hint: "Name"),
            InputData("LangText", hint: "Beschreibung"),
          ],
        ),
      );
}
