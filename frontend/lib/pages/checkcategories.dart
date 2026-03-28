import 'dart:async';

import 'package:MBG_Inspektionen/backend/categoryProgressState.dart';
import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/helpers/createEditor.dart';
import 'package:MBG_Inspektionen/options.dart';
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
  static const predefinedCategories = [
    "Weg zum Mast",
    "Funkraum Container",
    "Kabelrinne",
    "Bühnen",
    "Anschlagpunkte",
    "Fundamente",
    "Blitzschutz Erdung",
    "Tragwerk",
    "Antennen & Antennenhalterungen",
    "Steigweg",
    "Kabel & Kabelweg",
    "Abspannungen Pardunen",
    "Flugfeuer",
    "Rettungsgerät",
    "Standortschließung Tresor"
  ];

  CategoryModel(InspectionLocation location) : super(location);

  @override
  List<MyListTileData> actions = [
    MyListTileData(
      title: _nextViewTitle,
      icon: Icons.checklist,
    ),
    if (!omitDetailsInLevel2and3)
      MyListTileData(
        title: S.current!.imagesButton,
        icon: Icons.photo_library,
      ),
    if (!omitDetailsInLevel2and3)
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
    if (tiledata.title == _nextViewTitle) {
      final checkPointsModel = generateNextModel(data);
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (newcontext) =>
              nextModel<CheckPoint, CheckCategory, CheckPointsModel>(
            checkPointsModel,
          ),
        ),
      )
          .then((_) {
        unawaited(_updateRecentCategoryProgress(data, checkPointsModel));
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (newcontext) {
        if (tiledata.title == S.current!.imagesButton) {
          return standard_statefulImageView(this, data);
        }
        return alwaysPlainText(
            this, data, ((CheckCategory p0, p1) => update(p0, langText: p1)));
      }),
    );
  }

  Future<void> _updateRecentCategoryProgress(
    CheckCategory category,
    CheckPointsModel checkPointsModel,
  ) async {
    final now = DateTime.now();
    final checkpoints = await checkPointsModel.all().last;
    CategoryProgressState.instance.setTotal(
      categoryId: category.id,
      totalCheckpoints: checkpoints.length,
    );

    if (checkpoints.isEmpty) {
      CategoryProgressState.instance.clear(category.id);
      return;
    }

    final completionStates = await Future.wait(
      checkpoints.map((checkpoint) {
        return _isCheckpointEdited(
          checkPointsModel,
          checkpoint,
          now: now,
        );
      }),
    );

    final completedCheckpoints = completionStates.where((it) => it).length;
    if (completedCheckpoints <= 0) {
      CategoryProgressState.instance.clear(category.id);
      return;
    }

    CategoryProgressState.instance.upsert(
      categoryId: category.id,
      totalCheckpoints: checkpoints.length,
      completedCheckpoints: completedCheckpoints,
      updatedAt: now,
    );
  }

  Future<bool> _isCheckpointEdited(
    CheckPointsModel checkPointsModel,
    CheckPoint checkpoint, {
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final checkpointKey = CategoryProgressState.checkpointKey(
      pjNr: checkpoint.pjNr,
      categoryIndex: checkpoint.category_index,
      checkpointIndex: checkpoint.index,
    );

    if (CategoryProgressState.instance
        .checkpointEditedRecently(checkpointKey, now: effectiveNow)) {
      return true;
    }

    final cutoff = effectiveNow.subtract(CategoryProgressState.recentWindow);
    final defectsModel = checkPointsModel.generateNextModel(checkpoint);
    final defects = await defectsModel.all().last;
    return defects.any((defect) => _isRecentRealDefect(defect, cutoff));
  }

  bool _isRecentRealDefect(CheckPointDefect defect, DateTime cutoff) {
    if (defect.ereArt == 5204) {
      return false;
    }
    if (defect.erDate != null && defect.erDate!.isAfter(cutoff)) {
      return true;
    }
    if (defect.forceOffline) {
      return true;
    }
    if (defect.id.startsWith(LOCALLY_ADDED_PREFIX)) {
      return true;
    }
    return false;
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
          dropdown: predefinedCategories,
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
