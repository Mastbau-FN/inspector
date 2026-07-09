import 'package:MBG_Inspektionen/backend/local.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counts recent mangelfrei entries as checkpoint progress', () {
    final cutoff = DateTime(2026, 7, 1);
    final mangelfrei = _defect(ereArt: 5204)..erDate = DateTime(2026, 7, 2);

    expect(isRecentCheckpointProgressEntry(mangelfrei, cutoff), isTrue);
  });

  test('counts locally added mangelfrei entries as checkpoint progress', () {
    final cutoff = DateTime(2026, 7, 1);
    final mangelfrei = _defect(ereArt: 5204)
      ..id = '${LOCALLY_ADDED_PREFIX}mangelfrei';

    expect(isRecentCheckpointProgressEntry(mangelfrei, cutoff), isTrue);
  });

  test('does not count stale non-local checkpoint entries as recent progress',
      () {
    final cutoff = DateTime(2026, 7, 1);
    final mangelfrei = _defect(ereArt: 5204)..erDate = DateTime(2026, 6, 1);

    expect(isRecentCheckpointProgressEntry(mangelfrei, cutoff), isFalse);
  });
}

CheckPointDefect _defect({required int ereArt}) {
  return CheckPointDefect(
    pjNr: 123,
    category_index: 1,
    check_index: 1,
    index: 1,
    ereArt: ereArt,
  )..id = 'defect';
}
