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

import 'package:MBG_Inspektionen/l10n/locales.dart';

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
      title: S.current!.imagesButton,
      icon: Icons.photo_library,
    ),
    MyListTileData(
      title: S.current!.commentsOrDetailsButton,
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
        if (tiledata.title == S.current!.imagesButton)
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
  Widget? floatingActionButton(BuildContext context) {
    return PopUpActionbutton(
      expandedChild: (onCancel) => adder(
        parent: currentData,
        onCancel: onCancel,
        onDone: (category) async {
          await API().setNew(category, caller: currentData);
          notifyListeners();
        },
      ),
    );
  }

  static Adder adder({
    required InspectionLocation parent,
    required onCancel(),
    required onDone(CheckCategory category),
    CheckCategory? currentCategory,
  }) {
    return Adder(
      'category',
      onSet: (json) {
        Map<String, dynamic> category = json['category'];
        if (currentCategory != null) {
          category = currentCategory.toJson()..addAll(category);
        } else {
          category['PjNr'] = parent.pjNr;
          category['E1'] = -1;
        }
        onDone(CheckCategory.fromJson(category)!);
      },
      onCancel: onCancel,
      textfieldList: [
        InputData(
          "KurzText",
          hint: S.current!.kurzTextHint,
          value: currentCategory?.kurzText,
        ),
        InputData(
          "LangText",
          hint: S.current!.langTextHint,
          verify: InputData.alwaysCorrect,
          value: currentCategory?.langText,
        ),
      ],
    );
  }
}
