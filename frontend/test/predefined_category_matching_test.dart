import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/l10n/app_localizations_de.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:MBG_Inspektionen/pages/checkcategories.dart';
import 'package:MBG_Inspektionen/pages/checkpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('antenna templates tolerate connector variants from older versions', () {
    final expected = getPredefinedCategory(
      'Antennen & Antennenhalterungen',
    );

    expect(expected, isNotEmpty);
    expect(getPredefinedCategory('Antennen und Antennenhalterungen'), expected);
    expect(getPredefinedCategory('Antennen Antennenhalterungen'), expected);
    expect(
      getPredefinedCategory('Antennen &amp; Antennenhalterungen'),
      expected,
    );
  });

  test('category editor preserves ampersands from predefined names', () {
    S.current = AppLocalizationsDe();
    final inspection = InspectionLocation(pjNr: 123, stONr: 1)
      ..id = 'inspection';
    final editor = CategoryModel.adder(
      parent: inspection,
      onCancel: () {},
      onDone: (_) {},
    );

    expect(
      editor.textfieldList.first.postProcess(
        ' Antennen & Antennenhalterungen ',
      ),
      'Antennen & Antennenhalterungen',
    );
  });
}
