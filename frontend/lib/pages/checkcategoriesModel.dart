import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpointsModel.dart';
import 'package:MBG_Inspektionen/pages/detailsPage.dart';
import 'package:MBG_Inspektionen/pages/dropdown/dropdownModel.dart';

import 'imageView.dart';

class CategoryModel extends DropDownModel<CheckCategory> {
  final Backend _b = Backend();
  final InspectionLocation currentLocation;

  static const _nextViewTitle = "Prüfpunkte";

  CategoryModel(this.currentLocation);

  Future<List<CheckCategory>> get all async =>
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
            return nextModel(CheckPointsModel(data));
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
