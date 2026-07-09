import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:MBG_Inspektionen/l10n/app_localizations_de.dart';
import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps adder action buttons above the keyboard', (tester) async {
    S.current = AppLocalizationsDe();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Adder(
            'category',
            onCancel: () {},
            textfieldList: [
              InputData('KurzText', hint: 'KurzText'),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final buttonBottom =
        tester.getBottomLeft(find.byIcon(Icons.check_circle_outline)).dy;

    expect(buttonBottom, lessThanOrEqualTo(500));
  });
}
