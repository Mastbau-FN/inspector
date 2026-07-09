import 'package:MBG_Inspektionen/pages/location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enables editing and saves the entered StandortInfo',
      (tester) async {
    String? savedValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationEditableField(
            label: 'Eigentümer',
            text: 'Alt',
            onChanged: (value) => savedValue = value,
          ),
        ),
      ),
    );

    expect(find.text('Alt'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);

    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Neu');
    await tester.tap(find.byTooltip('Speichern'));
    await tester.pumpAndSettle();

    expect(savedValue, 'Neu');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Neu'), findsOneWidget);
  });

  testWidgets('cancels editing without discarding the last saved value',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationEditableField(
            label: 'Steigweg',
            text: 'Leiter',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Treppe');
    await tester.tap(find.byTooltip('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Leiter'), findsOneWidget);
    expect(find.text('Treppe'), findsNothing);
  });

  testWidgets('keeps invalid values editable and shows the validation error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationEditableField(
            label: 'Baujahr',
            text: '2020',
            validator: (value) =>
                int.tryParse(value) == null ? 'Ungültige Zahl' : null,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.byTooltip('Speichern'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Ungültige Zahl'), findsOneWidget);
  });
}
