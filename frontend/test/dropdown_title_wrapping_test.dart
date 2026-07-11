import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/pages/dropDownPageB.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows check category and checkpoint titles without ellipsis',
      (tester) async {
    final category = CheckCategory(
      pjNr: 123,
      index: 1,
      kurzText: 'Sehr langer Prüfkategoriename der vollständig sichtbar bleibt',
    )..id = 'category';
    final checkpoint = CheckPoint(
      pjNr: 123,
      category_index: 1,
      index: 1,
      kurzText: 'Sehr langer Prüfpunktname der vollständig sichtbar bleibt',
    )..id = 'checkpoint';

    late Text categoryText;
    late Text checkpointText;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            categoryText = dropdownItemTitleText(context, category);
            checkpointText = dropdownItemTitleText(context, checkpoint);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(categoryText.maxLines, isNull);
    expect(categoryText.overflow, TextOverflow.visible);
    expect(categoryText.softWrap, isTrue);
    expect(checkpointText.maxLines, isNull);
    expect(checkpointText.overflow, TextOverflow.visible);
    expect(checkpointText.softWrap, isTrue);
  });

  testWidgets('keeps inspection titles capped to avoid huge list rows',
      (tester) async {
    final inspection = InspectionLocation(pjNr: 123, stONr: 7)..id = 'insp';

    late Text inspectionText;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            inspectionText = dropdownItemTitleText(context, inspection);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(inspectionText.maxLines, 2);
    expect(inspectionText.overflow, TextOverflow.ellipsis);
  });
}
