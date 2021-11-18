import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefectsModel.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownModel.dart';

import 'detailsPage.dart';
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
            return ImageView.futured(
              future_images: data.image_futures,
              onNewImages: (files) => Backend().uploadFiles(data, files),
            );

          default:
            return DetailsPage(
                title: data.title,
                details: data.langText,
                onChanged: (txt) {/*TODO*/});
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
