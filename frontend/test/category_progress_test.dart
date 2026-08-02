import 'package:MBG_Inspektionen/backend/categoryProgressState.dart';
import 'package:MBG_Inspektionen/backend/sync_events.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/data/checkpoint.dart';
import 'package:MBG_Inspektionen/classes/listTileData.dart';
import 'package:MBG_Inspektionen/pages/dropDownPageB.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final progress = CategoryProgressState.instance;

  setUp(() async {
    await progress.waitForPendingPersistence();
    SharedPreferences.setMockInitialValues({});
    progress.reset();
    await progress.waitForPendingPersistence();
  });

  test('completed checkpoints survive an app restart', () async {
    progress.registerCategory(
      categoryId: 'category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 2,
    );
    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
      categoryId: 'category',
      checkpointId: 'checkpoint',
    );
    await progress.waitForPendingPersistence();

    progress.reset(clearPersisted: false);
    expect(progress.entryFor('category'), isNull);

    await progress.restore();

    expect(progress.entryFor('category')?.completedCheckpoints, 1);
    expect(
      progress.checkpointCompleted(
        checkpointId: 'checkpoint',
        pjNr: 123,
        categoryIndex: 4,
        checkpointIndex: 9,
      ),
      isTrue,
    );
  });

  test('opening a category does not mark checkpoints as completed', () {
    progress.registerCategory(
      categoryId: 'category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );

    expect(progress.entryFor('category'), isNull);
    expect(progress.totalFor('category'), 55);
  });

  test('creating a checkpoint increments the category total', () {
    progress.registerCategory(
      categoryId: 'category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );

    progress.checkpointAdded(categoryId: 'category');

    expect(progress.totalFor('category'), 56);
    expect(progress.entryFor('category'), isNull);
  });

  test('deleting a completed checkpoint updates total and completion', () {
    progress.registerCategory(
      categoryId: 'category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 2,
    );
    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
      categoryId: 'category',
      checkpointId: 'checkpoint',
    );

    progress.checkpointRemoved(
      categoryId: 'category',
      checkpointId: 'checkpoint',
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
    );

    expect(progress.totalFor('category'), 1);
    expect(progress.entryFor('category'), isNull);
  });

  test('successful sync resets and reloads progress for all inspections', () {
    progress.registerCategory(
      categoryId: 'first-category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );
    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
      categoryId: 'first-category',
      checkpointId: 'first-checkpoint',
    );
    progress.registerCategory(
      categoryId: 'second-category',
      pjNr: 456,
      categoryIndex: 1,
      totalCheckpoints: 12,
    );
    progress.markCheckpointEditedByCoordinates(
      pjNr: 456,
      categoryIndex: 1,
      checkpointIndex: 3,
      categoryId: 'second-category',
      checkpointId: 'second-checkpoint',
    );

    SyncEvents.instance.notifySyncCompleted();

    expect(progress.totalFor('first-category'), isNull);
    expect(progress.totalFor('second-category'), isNull);
    expect(progress.entryFor('first-category'), isNull);
    expect(progress.entryFor('second-category'), isNull);
    expect(
      progress.checkpointCompleted(
        checkpointId: 'first-checkpoint',
        pjNr: 123,
        categoryIndex: 4,
        checkpointIndex: 9,
      ),
      isFalse,
    );
    expect(
      progress.checkpointCompleted(
        checkpointId: 'second-checkpoint',
        pjNr: 456,
        categoryIndex: 1,
        checkpointIndex: 3,
      ),
      isFalse,
    );

    progress.registerCategory(
      categoryId: 'first-category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );
    progress.registerCategory(
      categoryId: 'second-category',
      pjNr: 456,
      categoryIndex: 1,
      totalCheckpoints: 12,
    );

    expect(progress.totalFor('first-category'), 55);
    expect(progress.totalFor('second-category'), 12);
    expect(progress.entryFor('first-category'), isNull);
    expect(progress.entryFor('second-category'), isNull);
  });

  test('creating a defect or mangelfrei marks exactly one checkpoint', () {
    progress.registerCategory(
      categoryId: 'category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );

    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
    );

    final entry = progress.entryFor('category');
    expect(entry?.completedCheckpoints, 1);
    expect(entry?.totalCheckpoints, 55);
    expect(entry?.progress, closeTo(1 / 55, 0.0001));
  });

  test('a completion recorded before total loading is retained', () {
    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
    );
    progress.registerCategory(
      categoryId: 'category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );

    expect(progress.entryFor('category')?.completedCheckpoints, 1);
  });

  test('registered category wins over a stale checkpoint parent id', () {
    progress.registerCategory(
      categoryId: 'current-category',
      pjNr: 123,
      categoryIndex: 4,
      totalCheckpoints: 55,
    );

    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: 4,
      checkpointIndex: 9,
      categoryId: 'stale-category',
      checkpointId: 'checkpoint',
    );

    expect(
      progress.entryFor('current-category')?.completedCheckpoints,
      1,
    );
    expect(progress.entryFor('stale-category'), isNull);
  });

  test('offline categories with minus one indexes remain separate', () {
    progress.registerCategory(
      categoryId: 'offline-category-a',
      pjNr: 123,
      categoryIndex: -1,
      totalCheckpoints: 2,
    );
    progress.markCheckpointEditedByCoordinates(
      pjNr: 123,
      categoryIndex: -1,
      checkpointIndex: -1,
      categoryId: 'offline-category-a',
      checkpointId: 'offline-checkpoint-a',
    );
    progress.registerCategory(
      categoryId: 'offline-category-b',
      pjNr: 123,
      categoryIndex: -1,
      totalCheckpoints: 3,
    );

    expect(
      progress.entryFor('offline-category-a')?.completedCheckpoints,
      1,
    );
    expect(progress.entryFor('offline-category-b'), isNull);
  });

  testWidgets('completed checkpoints are fully green without count label',
      (tester) async {
    final checkpoint = CheckPoint(
      pjNr: 123,
      category_index: 4,
      index: 9,
      kurzText: 'Kennzeichnung Zuwegung',
    )..id = 'checkpoint';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropDownElementB<CheckPoint>(
            cd: checkpoint,
            completionPercent: 1,
            actions: [MyListTileData(title: 'Mängel', icon: Icons.list)],
            onAction: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('dropdown.completion.checkpoint')), findsOne);
    expect(
      find.byKey(const Key('dropdown.progress-label.checkpoint')),
      findsNothing,
    );
  });

  testWidgets('category count is below the unshortened title', (tester) async {
    final category = CheckCategory(
      pjNr: 123,
      index: 4,
      kurzText:
          'Sehr lange Prüfkategorie mit vollständig sichtbarem Kategorienamen',
    )..id = 'category';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DropDownElementB<CheckCategory>(
            cd: category,
            completionPercent: 0.5,
            completionLabel: '5/10 bearbeitet',
            actions: [
              MyListTileData(title: 'Prüfpunkte', icon: Icons.list),
              MyListTileData(title: 'Fotos', icon: Icons.photo_library),
            ],
            onAction: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final titleFinder = find.byKey(const Key('dropdown.title.category'));
    final labelFinder =
        find.byKey(const Key('dropdown.progress-label.category'));
    expect(titleFinder, findsOneWidget);
    expect(labelFinder, findsOneWidget);
    expect(tester.getTopLeft(labelFinder).dy,
        greaterThan(tester.getTopLeft(titleFinder).dy));
    final title = tester.widget<Text>(
      find.descendant(of: titleFinder, matching: find.byType(Text)),
    );
    expect(title.maxLines, isNull);
    expect(title.overflow, TextOverflow.visible);
    expect(find.byKey(const Key('dropdown.actions.category')), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Fotos'), findsOneWidget);
  });
}
