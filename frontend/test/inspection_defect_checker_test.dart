import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/pages/inspection_defect_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only considers defect entries belonging to the selected inspection',
      () async {
    final freshInspection = _inspection('fresh-inspection');
    final existingInspection = _inspection('existing-inspection');
    final freshCategory = _category('fresh-category');
    final existingCategory = _category('existing-category');
    final freshCheckpoint = _checkpoint('fresh-checkpoint');
    final existingCheckpoint = _checkpoint('existing-checkpoint');
    final existingDefect = _defect('existing-defect', ereArt: 5202);

    final checker = InspectionDefectChecker(
      loadCategories: (inspection) async => switch (inspection.id) {
        'fresh-inspection' => [freshCategory],
        'existing-inspection' => [existingCategory],
        _ => [],
      },
      loadCheckpoints: (category) async => switch (category.id) {
        'fresh-category' => [freshCheckpoint],
        'existing-category' => [existingCheckpoint],
        _ => [],
      },
      loadDefects: (checkpoint) async =>
          checkpoint.id == 'existing-checkpoint' ? [existingDefect] : [],
    );

    expect(await checker.hasDefectEntries(freshInspection), isFalse);
    expect(await checker.hasDefectEntries(existingInspection), isTrue);
  });

  test('counts a mangelfrei entry as an existing defect entry', () async {
    final inspection = _inspection('inspection');
    final category = _category('category');
    final checkpoint = _checkpoint('checkpoint');
    final mangelfrei = _defect('mangelfrei', ereArt: 5204);
    final checker = InspectionDefectChecker(
      loadCategories: (_) async => [category],
      loadCheckpoints: (_) async => [checkpoint],
      loadDefects: (_) async => [mangelfrei],
    );

    expect(await checker.hasDefectEntries(inspection), isTrue);
  });

  test('ignores entries with an explicit foreign parent id', () async {
    final inspection = _inspection('current-inspection');
    final currentCategory = _category('current-category')
      ..parentId = inspection.id;
    final foreignCategory = _category('foreign-category')
      ..parentId = 'other-inspection';
    final currentCheckpoint = _checkpoint('current-checkpoint')
      ..parentId = currentCategory.id;
    final foreignCheckpoint = _checkpoint('foreign-checkpoint')
      ..parentId = 'other-category';
    final foreignDefect = _defect('foreign-defect', ereArt: 5202)
      ..parentId = 'other-checkpoint';

    final checker = InspectionDefectChecker(
      loadCategories: (_) async => [currentCategory, foreignCategory],
      loadCheckpoints: (category) async => switch (category.id) {
        'current-category' => [currentCheckpoint, foreignCheckpoint],
        'foreign-category' => [_checkpoint('ignored-checkpoint')],
        _ => [],
      },
      loadDefects: (checkpoint) async => switch (checkpoint.id) {
        'current-checkpoint' => [foreignDefect],
        'foreign-checkpoint' => [foreignDefect],
        _ => [_defect('ignored-defect', ereArt: 5202)],
      },
    );

    expect(await checker.hasDefectEntries(inspection), isFalse);
  });

  test('inspection parent query includes inspection-specific identifiers', () {
    final inspection = _inspection(
      'inspection-id',
      stONr: 42,
      loginIdPruefer: '987',
    );

    expect(inspection.toSmallJson(), {
      'PjNr': 123,
      'StONr': 42,
      'Login_ID_Pruefer': '987',
      'local_id': 'inspection-id',
    });
  });

  test('bounds concurrent defect lookups while avoiding serial latency',
      () async {
    final inspection = _inspection('inspection');
    final category = _category('category')..parentId = inspection.id;
    final checkpoints = List.generate(
      9,
      (index) => _checkpoint('checkpoint-$index')..parentId = category.id,
    );
    var activeLoads = 0;
    var peakLoads = 0;

    final checker = InspectionDefectChecker(
      maxConcurrentLoads: 3,
      loadCategories: (_) async => [category],
      loadCheckpoints: (_) async => checkpoints,
      loadDefects: (_) async {
        activeLoads++;
        if (activeLoads > peakLoads) peakLoads = activeLoads;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activeLoads--;
        return [];
      },
    );

    expect(await checker.hasDefectEntries(inspection), isFalse);
    expect(peakLoads, 3);
  });
}

InspectionLocation _inspection(
  String id, {
  int stONr = 7,
  String? loginIdPruefer,
}) {
  final inspection = InspectionLocation(pjNr: 123, stONr: stONr);
  inspection.id = id;
  inspection.login_id_pruefer = loginIdPruefer;
  return inspection;
}

CheckCategory _category(String id) {
  final category = CheckCategory(pjNr: 123, index: 1);
  category.id = id;
  return category;
}

CheckPoint _checkpoint(String id) {
  final checkpoint = CheckPoint(
    pjNr: 123,
    category_index: 1,
    index: 1,
  );
  checkpoint.id = id;
  return checkpoint;
}

CheckPointDefect _defect(String id, {required int ereArt}) {
  final defect = CheckPointDefect(
    pjNr: 123,
    category_index: 1,
    check_index: 1,
    index: 1,
    ereArt: ereArt,
  );
  defect.id = id;
  return defect;
}
