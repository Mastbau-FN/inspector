import 'package:MBG_Inspektionen/fragments/adder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first dropdown option stays tappable below the status bar',
      (tester) async {
    const statusBarHeight = 24.0;
    const firstOption = 'Tragkonstruktion';

    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 640),
            padding: EdgeInsets.only(top: statusBarHeight),
            viewInsets: EdgeInsets.only(bottom: 280),
          ),
          child: child!,
        ),
        home: Adder(
          'checkpoint',
          textfieldList: [
            InputData(
              'KurzText',
              hint: 'Name',
              dropdown: const [
                firstOption,
                'Gitterroste',
                'Gitterrostklemmen',
                'Verbindungsmittel',
                'Geländer',
              ],
            ),
            InputData(
              'LangText',
              hint: 'Beschreibung',
              verify: InputData.alwaysCorrect,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('adder.dropdown.button.Name')),
    );
    await tester.pumpAndSettle();

    final firstOptionFinder =
        find.byKey(const ValueKey('adder.dropdown.option.$firstOption'));
    expect(firstOptionFinder, findsOneWidget);
    expect(
      tester.getTopLeft(firstOptionFinder).dy,
      greaterThanOrEqualTo(statusBarHeight),
    );

    await tester.tap(firstOptionFinder);
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller?.text, firstOption);
  });
}
