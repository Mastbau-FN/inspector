import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:MBG_Inspektionen/pages/dokusPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides operating-system metadata from the document list',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DokusList(
          dokus: [
            DocumentData(
              filename: 'Thumbs.db',
              docupath: r'C:\Inspektion\Doku\Thumbs.db',
            ),
            DocumentData(
              filename: 'Pruefplan.pdf',
              docupath: r'C:\Inspektion\Doku\Pruefplan.pdf',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Pruefplan.pdf'), findsOneWidget);
    expect(find.text('Thumbs.db'), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });
}
