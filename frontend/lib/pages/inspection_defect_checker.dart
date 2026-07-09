import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:MBG_Inspektionen/pages/checkpoints.dart';

typedef InspectionCategoryLoader = Future<List<CheckCategory>> Function(
  InspectionLocation inspection,
);
typedef CategoryCheckpointLoader = Future<List<CheckPoint>> Function(
  CheckCategory category,
);
typedef CheckpointDefectLoader = Future<List<CheckPointDefect>> Function(
  CheckPoint checkpoint,
);

class InspectionDefectChecker {
  InspectionDefectChecker({
    InspectionCategoryLoader? loadCategories,
    CategoryCheckpointLoader? loadCheckpoints,
    CheckpointDefectLoader? loadDefects,
  })  : _loadCategories = loadCategories ?? _defaultLoadCategories,
        _loadCheckpoints = loadCheckpoints ?? _defaultLoadCheckpoints,
        _loadDefects = loadDefects ?? _defaultLoadDefects;

  final InspectionCategoryLoader _loadCategories;
  final CategoryCheckpointLoader _loadCheckpoints;
  final CheckpointDefectLoader _loadDefects;

  Future<bool> hasDefectEntries(InspectionLocation inspection) async {
    final categories = (await _loadCategories(inspection))
        .where((category) => _belongsToParent(category, inspection.id));
    for (final category in categories) {
      final checkpoints = (await _loadCheckpoints(category))
          .where((checkpoint) => _belongsToParent(checkpoint, category.id));
      for (final checkpoint in checkpoints) {
        final defects = (await _loadDefects(checkpoint))
            .where((defect) => _belongsToParent(defect, checkpoint.id));
        if (defects.isNotEmpty) return true;
      }
    }
    return false;
  }

  static Future<List<CheckCategory>> _defaultLoadCategories(
    InspectionLocation inspection,
  ) =>
      CategoryModel(inspection).all().last;

  static Future<List<CheckPoint>> _defaultLoadCheckpoints(
    CheckCategory category,
  ) =>
      CheckPointsModel(category).all().last;

  static Future<List<CheckPointDefect>> _defaultLoadDefects(
    CheckPoint checkpoint,
  ) =>
      CheckPointDefectsModel(checkpoint).all().last;

  static bool _belongsToParent(WithOffline data, String parentId) {
    final explicitParentId = data.parentId?.trim();
    return explicitParentId == null ||
        explicitParentId.isEmpty ||
        explicitParentId == parentId;
  }
}
