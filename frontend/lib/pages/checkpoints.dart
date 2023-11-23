import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';

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
    if (!omitDetailsInLevel2and3)
      MyListTileData(
        title: "Fotos",
        icon: Icons.photo_library,
      ),
    if (!omitDetailsInLevel2and3)
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
            return alwaysPlainText(
                this, data, ((CheckPoint p0, p1) => update(p0, langText: p1)));
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
    required CheckCategory parent,
    required onCancel(),
    required onDone(CheckPoint checkpoint),
    CheckPoint? currentCheckpoint,
  }) {
    return Adder(
      'checkpoint',
      onSet: (json) {
        Map<String, dynamic> checkpoint = json['checkpoint'];
        if (currentCheckpoint != null) {
          checkpoint = currentCheckpoint.toJson()..addAll(checkpoint);
        } else {
          checkpoint['PjNr'] = parent.pjNr;
          checkpoint['E1'] = parent.index;
          checkpoint['E2'] = -1;
        }
        onDone(CheckPoint.fromJson(checkpoint)!);
      },
      onCancel: onCancel,
      textfieldList: [
        InputData(
          "KurzText",
          hint: S.current!.kurzTextHint,
          value: currentCheckpoint?.kurzText,
        ),
        InputData(
          "LangText",
          hint: S.current!.langTextHint,
          verify: InputData.alwaysCorrect,
          value: currentCheckpoint?.langText,
        ),
      ],
    );
  }
}
