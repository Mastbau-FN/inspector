import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/generated/l10n.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

import 'detailsPage.dart';
import 'imagesPage.dart';

class CheckPointsModel extends DropDownModel<CheckPoint, CheckCategory>
    implements KnowsNext<CheckPoint> {
  CheckPointsModel(CheckCategory p) : super(p);

  static const _nextViewTitle = "Mängel";

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
  CheckPointDefectsModel generateNextModel(CheckPoint data) {
    return CheckPointDefectsModel(data);
  }

  @override
  void open(
    BuildContext context,
    CheckPoint data,
    MyListTileData tiledata,
  ) {
    currentlyChosenChildData = Future.value(data);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        switch (tiledata.title) {
          case _nextViewTitle:
            return nextModel<CheckPointDefect, CheckPoint,
                CheckPointDefectsModel>(generateNextModel(data));
          case 'Fotos':
            return standard_statefulImageView(this, data);

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
            Map<String, dynamic> checkpoint = json['checkpoint'];
            checkpoint['PjNr'] = currentData.pjNr;
            checkpoint['E1'] = currentData.index;
            checkpoint['E2'] = -1;
            await Backend().setNew(CheckPoint.fromJson(checkpoint));
            notifyListeners();
          },
          onCancel: onCancel,
          textfield_list: [
            InputData("KurzText", hint: S.current.kurzTextHint),
            InputData("LangText",
                hint: S.current.langTextHint, verify: InputData.alwaysCorrect),
          ],
        ),
      );
}
