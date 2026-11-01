import 'package:MBG_Inspektionen/backend/inspection_download_warnings.dart';
import 'package:MBG_Inspektionen/backend/download_progress.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists distinct files with all locations only for their inspection',
      () async {
    await saveInspectionDownloadWarnings('inspection:123:7', [
      _warning('empty.jpg', 'Zuwegung'),
      _warning('empty.jpg', 'Tresor'),
      _warning('other.jpg', 'Mast'),
    ]);

    final restored = await loadInspectionDownloadWarnings('inspection:123:7');
    expect(restored, hasLength(2));
    expect(restored.first.filename, 'empty.jpg');
    expect(restored.first.locations, ['Zuwegung', 'Tresor']);
    expect(restored.last.filename, 'other.jpg');
    expect(await loadInspectionDownloadWarnings('inspection:456:7'), isEmpty);

    await saveInspectionDownloadWarnings('inspection:123:7', []);
    expect(await loadInspectionDownloadWarnings('inspection:123:7'), isEmpty);
  });

  testWidgets(
      'completed download shows green check and persistent file details',
      (tester) async {
    await saveInspectionDownloadWarnings('inspection:123:7', [
      _warning('empty1.jpg', 'Weg zum Mast / Kennzeichnung Zuwegung'),
      _warning('empty2.jpg', 'Standortschließung / Tresor'),
      _warning('empty3.jpg', 'Weg zum Mast / sonstiges / ohne Mangel'),
    ]);

    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    final details = find.byTooltip('Download erfolgreich – 3 Dateien prüfen');
    expect(details, findsOneWidget);
    await tester.tap(details);
    await tester.pumpAndSettle();

    expect(find.text('Download erfolgreich'), findsOneWidget);
    for (final filename in ['empty1.jpg', 'empty2.jpg', 'empty3.jpg']) {
      expect(find.text(filename), findsOneWidget);
    }
    expect(find.textContaining('0 Byte'), findsOneWidget);
    expect(find.text('Standortschließung / Tresor'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Download erfolgreich – 3 Dateien prüfen'),
        findsOneWidget);
  });

  testWidgets('a repaired redownload clears the warning badge', (tester) async {
    await saveInspectionDownloadWarnings('inspection:123:7', [
      _warning('empty.jpg', 'Tresor'),
    ]);
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    expect(find.byType(Badge), findsOneWidget);

    await saveInspectionDownloadWarnings('inspection:123:7', []);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets(
      'a recreated button shows completion and refreshed warning details',
      (tester) async {
    final progress = DownloadProgress.instance;
    final session = progress.start(key: 'inspection:123:7');
    addTearDown(() => progress.finish(session));
    await tester.pumpWidget(_overview(offline: false));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await saveInspectionDownloadWarnings('inspection:123:7', [
      _warning('empty.jpg', 'Tresor'),
    ]);
    progress.finish(session, succeeded: true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byTooltip('Download erfolgreich – 1 Datei prüfen'),
        findsOneWidget);

    final recheck = progress.start(key: 'inspection:123:7');
    await tester.pump();
    await saveInspectionDownloadWarnings('inspection:123:7', []);
    progress.finish(recheck, succeeded: true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('warning details tolerate the inspection view being disposed',
      (tester) async {
    await saveInspectionDownloadWarnings('inspection:123:7', [
      _warning('empty.jpg', 'Tresor'),
    ]);
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    final openDetails = tester
        .widget<IconButton>(
          find.byWidgetPredicate((widget) =>
              widget is IconButton &&
              widget.tooltip?.startsWith('Download erfolgreich –') == true),
        )
        .onPressed!;

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();
    expect(openDetails, returnsNormally);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Fertig keeps reviewed files quiet after reopening and redownload',
      (tester) async {
    final warnings = [
      _warning('empty1.jpg', 'Zuwegung'),
      _warning('empty2.jpg', 'Tresor'),
      _warning('empty3.jpg', 'Mast'),
    ];
    await saveInspectionDownloadWarnings('inspection:123:7', warnings);
    await saveInspectionDownloadWarnings('inspection:456:7', warnings);
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download erfolgreich – 3 Dateien prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Fertig'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Badge), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(await loadInspectionDownloadWarnings('inspection:123:7'), isEmpty);
    expect(
        await loadInspectionDownloadWarnings('inspection:456:7'), hasLength(3));

    await saveInspectionDownloadWarnings('inspection:123:7', warnings);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    expect(find.byType(Badge), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('new files still appear after Fertig', (tester) async {
    final reviewed = _warning('known.jpg', 'Zuwegung');
    await saveInspectionDownloadWarnings('inspection:123:7', [reviewed]);
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download erfolgreich – 1 Datei prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Fertig'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    await saveInspectionDownloadWarnings('inspection:123:7', [
      reviewed,
      _warning('new.jpg', 'Tresor'),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download erfolgreich – 1 Datei prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('new.jpg'), findsOneWidget);
    expect(find.text('known.jpg'), findsNothing);
  });

  testWidgets('a repaired file is reported if it later becomes empty again',
      (tester) async {
    final warning = _warning('photo.jpg', 'Tresor');
    await saveInspectionDownloadWarnings('inspection:123:7', [warning]);
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download erfolgreich – 1 Datei prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Fertig'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    await saveInspectionDownloadWarnings('inspection:123:7', []);
    await saveInspectionDownloadWarnings('inspection:123:7', [warning]);
    await tester.pumpAndSettle();
    expect(find.byType(Badge), findsOneWidget);
    expect(
        (await loadInspectionDownloadWarnings('inspection:123:7'))
            .single
            .filename,
        'photo.jpg');
  });

  testWidgets('Fertig acknowledges only the files shown in the open dialog',
      (tester) async {
    final shown = _warning('shown.jpg', 'Zuwegung');
    await saveInspectionDownloadWarnings('inspection:123:7', [shown]);
    await tester.pumpWidget(_overview());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download erfolgreich – 1 Datei prüfen'));
    await tester.pumpAndSettle();
    await saveInspectionDownloadWarnings('inspection:123:7', [
      shown,
      _warning('unseen.jpg', 'Tresor'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('unseen.jpg'), findsNothing);
    expect(find.text('Fertig'), findsOneWidget);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    expect(find.byType(Badge), findsOneWidget);
    expect(
        (await loadInspectionDownloadWarnings('inspection:123:7'))
            .single
            .filename,
        'unseen.jpg');
  });

}

InspectionDownloadWarning _warning(String filename, String location) =>
    InspectionDownloadWarning(
      hash: filename,
      filename: filename,
      locations: [location],
    );

Widget _overview({bool offline = true}) {
  final inspection = InspectionLocation(pjNr: 123, stONr: 7)
    ..id = 'inspection'
    ..forceOffline = offline;
  return MaterialApp(
    home: Scaffold(body: Center(child: Row(children: inspection.extras()))),
  );
}
