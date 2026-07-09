import 'dart:async';

import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/data/checkpointdefect.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/pages/inspection_defect_checker.dart';
import 'package:MBG_Inspektionen/pages/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a progress dialog while checking inspection defects',
      (tester) async {
    final categoryCompleter = Completer<List<CheckCategory>>();
    final inspection = InspectionLocation(pjNr: 123, stONr: 7)
      ..id = 'inspection';
    final category = CheckCategory(pjNr: 123, index: 1)
      ..id = 'category'
      ..parentId = inspection.id;
    final checkpoint = CheckPoint(pjNr: 123, category_index: 1, index: 1)
      ..id = 'checkpoint'
      ..parentId = category.id;
    final defect = CheckPointDefect(
      pjNr: 123,
      category_index: 1,
      check_index: 1,
      index: 1,
      ereArt: 5202,
    )
      ..id = 'defect'
      ..parentId = checkpoint.id;

    final model = LocationModel(
      defectChecker: InspectionDefectChecker(
        loadCategories: (_) => categoryCompleter.future,
        loadCheckpoints: (_) async => [checkpoint],
        loadDefects: (_) async => [defect],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => model.open(
                context,
                inspection,
                MyListTileData(title: 'Prüfkategorien'),
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Öffnen'));
    await tester.pump();

    expect(find.text('Mängelprüfung'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    categoryCompleter.complete([category]);
    await tester.pumpAndSettle();

    expect(find.text('Mängelprüfung'), findsNothing);
    expect(find.text('Gefundene Mängel'), findsOneWidget);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
  });
}
