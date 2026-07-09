import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/l10n/app_localizations_de.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('opens category edit fullscreen and saves the category name',
      (tester) async {
    S.current = AppLocalizationsDe();

    final inspection = InspectionLocation(pjNr: 123, stONr: 7)..id = 'insp';
    final model = _RecordingCategoryModel(inspection);
    final category = CheckCategory(
      pjNr: 123,
      index: 1,
      kurzText: 'Alt',
      langText: 'Beschreibung',
    )..id = 'cat';

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<CategoryModel>.value(
          value: model,
          child: Builder(
            builder: (context) => Scaffold(
              body: category.editButton(context: context),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    expect(find.text('Kategorie bearbeiten'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first, 'Neu');
    await tester.tap(find.byIcon(Icons.check_circle_outline));
    await tester.pumpAndSettle();

    expect(model.updatedCategory?.kurzText, 'Neu');
    expect(model.updatedCategory?.langText, 'Beschreibung');
    expect(find.text('Kategorie bearbeiten'), findsNothing);
  });
}

class _RecordingCategoryModel extends CategoryModel {
  _RecordingCategoryModel(super.location);

  CheckCategory? updatedCategory;

  @override
  void update(CheckCategory data, {String? langText}) {
    if (langText != null) data.langText = langText;
    updatedCategory = data;
    notifyListeners();
  }
}
