import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpoints.dart';
import 'package:MBG_Inspektionen/pages/detailsPage.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

import 'imagesPage.dart';

class CategoryModel extends DropDownModel<CheckCategory> {
  final Backend _b = Backend();
  final InspectionLocation currentLocation;

  static const _nextViewTitle = "Prüfpunkte";

  CategoryModel(this.currentLocation);

  Future<List<CheckCategory>> get all =>
      _b.getAllCheckCategoriesForLocation(currentLocation);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.checklist,
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
  String get title => '$currentLocation';

  @override
  void open(
    BuildContext context,
    CheckCategory data,
    MyListTileData tiledata,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckPoint, CheckPointsModel>(
                CheckPointsModel(data));
          case 'Fotos':
            return ImagesPage.futured(
              future_images: data.image_streams,
              onNewImages: (files) => Backend().uploadFiles(data, files),
              onStar: (hash) =>
                  Backend().setMainImageByHash(data, hash.toString()),
            );

          default:
            return createRichIfPossibleEditor(data, uploadString);
        }
      }),
    );
  }

  void uploadString(CheckCategory data, txt) async {
    data.langText = txt;
    await _b.update(data);
    notifyListeners();
  }

  @override
  Widget? get floatingActionButton => TransformeableActionbutton(
        expandedHeight: 200,
        expandedChild: (onCancel) => Adder(
          'checkpoint',
          onSet: (json) async {
            Map<String, dynamic> category = json['checkpoint'];
            category['PjNr'] = currentLocation.pjNr;
            category['E1'] = -1;
            await Backend().setNew(CheckCategory.fromJson(category));
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
