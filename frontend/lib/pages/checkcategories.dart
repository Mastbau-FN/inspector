import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpoints.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

import '../generated/l10n.dart';

class CategoryModel extends DropDownModel<CheckCategory, InspectionLocation>
    implements KnowsNext<CheckCategory> {
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
  CheckPointsModel generateNextModel(CheckCategory data) {
    return CheckPointsModel(data);
  }

  @override
  void open(
    BuildContext context,
    CheckCategory data,
    MyListTileData tiledata,
  ) {
    currentlyChosenChildData = Future.value(data);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        if (tiledata.title == S.current.imagesButton)
          return standard_statefulImageView(this, data);
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckPoint, CheckCategory, CheckPointsModel>(
                generateNextModel(data));

          default:
            return alwaysPlainText(this, data,
                ((CheckCategory p0, p1) => update(p0, langText: p1)));
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
            await API()
                .setNew(CheckCategory.fromJson(category), caller: currentData);
            notifyListeners();
            // all = API().getNextDatapoint(currentData);
            // await Future.delayed(Duration(milliseconds: 5000));
            // notifyListeners();
          },
          onCancel: onCancel,
          textfieldList: [
            InputData("KurzText", hint: S.current.kurzTextHint),
            InputData("LangText",
                hint: S.current.langTextHint, verify: InputData.alwaysCorrect),
          ],
        ),
      );
}
