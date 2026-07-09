import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/pages/checkpointdefects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapses duplicate no-defect markers into one visible entry', () {
    final localNoDefect = _defect(
      id: '${LOCALLY_ADDED_PREFIX}no-defect',
      ereArt: OufnessChooser.none,
      erDate: DateTime(2026, 7, 1),
    );
    final syncedNoDefect = _defect(
      id: 'server-no-defect',
      ereArt: OufnessChooser.none,
      erDate: DateTime(2026, 7, 2),
    );

    final visible = normalizeCheckpointDefectsForDisplay([
      localNoDefect,
      syncedNoDefect,
      _defect(id: 'server-no-defect-duplicate', ereArt: OufnessChooser.none),
    ]);

    expect(visible, hasLength(1));
    expect(visible.single.id, 'server-no-defect');
  });

  test('hides no-defect marker when actual defects exist', () {
    final actualDefect = _defect(id: 'actual-defect', ereArt: 5202);

    final visible = normalizeCheckpointDefectsForDisplay([
      _defect(id: 'no-defect', ereArt: OufnessChooser.none),
      actualDefect,
    ]);

    expect(visible, [actualDefect]);
  });
}

CheckPointDefect _defect({
  required String id,
  required int ereArt,
  DateTime? erDate,
}) {
  return CheckPointDefect(
    pjNr: 123,
    category_index: 1,
    check_index: 1,
    index: ereArt == OufnessChooser.none ? -1 : 1,
    ereArt: ereArt,
    erDate: erDate,
  )..id = id;
}
