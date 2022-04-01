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

import '../generated/l10n.dart';
import 'imagesPage.dart';

class CategoryModel extends DropDownModel<CheckCategory, InspectionLocation> {
  static const _nextViewTitle = "Prüfpunkte";

  CategoryModel(InspectionLocation location) : super(location);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.checklist,
    ),
    MyListTileData(
      title: S.current.imagesButton,
      icon: Icons.photo_library,
    ),
    MyListTileData(
      title: S.current.commentsOrDetailsButton,
      icon: Icons.text_snippet,
    ),
  ];

  @override
  void open(
    BuildContext context,
    CheckCategory data,
    MyListTileData tiledata,
  ) {
    currentlyChosenChildData = Future.sync(() => data);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        if (tiledata.title == S.current.imagesButton)
          return standard_statefulImageView(this, data);
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckPoint, CheckCategory, CheckPointsModel>(
                CheckPointsModel(data));

          default:
            return alwaysPlainText(this, data, update);
        }
      }),
    );
  }

  @override
  Widget? get floatingActionButton => TransformableActionbutton(
        expandedHeight: 200,
        expandedChild: (onCancel) => Adder(
          'checkpoint',
          onSet: (json) async {
            Map<String, dynamic> category = json['checkpoint'];
            category['PjNr'] = currentData.pjNr;
            category['E1'] = -1;
            await Backend().setNew(CheckCategory.fromJson(category));
            notifyListeners();
          },
          onCancel: onCancel,
          textfield_list: [
            InputData("KurzText", hint: S.current.kurzTextHint),
            InputData("LangText", hint: S.current.langTextHint),
          ],
        ),
      );
}
