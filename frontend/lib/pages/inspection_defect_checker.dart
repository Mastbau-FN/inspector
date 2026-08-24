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
    int maxConcurrentLoads = 8,
  })  : _loadCategories = loadCategories ?? _defaultLoadCategories,
        _loadCheckpoints = loadCheckpoints ?? _defaultLoadCheckpoints,
        _loadDefects = loadDefects ?? _defaultLoadDefects,
        _maxConcurrentLoads = maxConcurrentLoads,
        assert(maxConcurrentLoads > 0);

  final InspectionCategoryLoader _loadCategories;
  final CategoryCheckpointLoader _loadCheckpoints;
  final CheckpointDefectLoader _loadDefects;
  final int _maxConcurrentLoads;

  Future<bool> hasDefectEntries(InspectionLocation inspection) async {
    final categories = (await _loadCategories(inspection))
        .where((category) => _belongsToParent(category, inspection.id))
        .toList(growable: false);

    final checkpoints = <CheckPoint>[];
    for (final batch in _batches(categories)) {
      final loaded = await Future.wait(
        batch.map((category) async {
          return (await _loadCheckpoints(category))
              .where((checkpoint) => _belongsToParent(checkpoint, category.id))
              .toList(growable: false);
        }),
      );
      for (final categoryCheckpoints in loaded) {
        checkpoints.addAll(categoryCheckpoints);
      }
    }

    // Each loader can include a backend round-trip. Running all checkpoints
    // one after another made an otherwise local-looking navigation take
    // 20-35 seconds. A small bounded batch keeps pressure off the backend but
    // removes the serial network latency.
    for (final batch in _batches(checkpoints)) {
      final containsDefect = await Future.wait(
        batch.map((checkpoint) async {
          return (await _loadDefects(checkpoint))
              .any((defect) => _belongsToParent(defect, checkpoint.id));
        }),
      );
      if (containsDefect.any((value) => value)) return true;
    }
    return false;
  }

  Iterable<List<T>> _batches<T>(List<T> values) sync* {
    for (var start = 0; start < values.length; start += _maxConcurrentLoads) {
      final proposedEnd = start + _maxConcurrentLoads;
      final end = proposedEnd < values.length ? proposedEnd : values.length;
      yield values.sublist(start, end);
    }
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
