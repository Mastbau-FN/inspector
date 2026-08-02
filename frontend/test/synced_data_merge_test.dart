import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replaces a stale local category with its synced server copy', () async {
    final local = CheckCategory(
      pjNr: 123,
      index: -1,
      kurzText: 'Antennen Antennenhalterungen',
      langText: 'Prüfung',
    )
      ..id = '__loc__category'
      ..forceOffline = true
      ..author = 'tester';
    final remote = CheckCategory(
      pjNr: 123,
      index: 7,
      kurzText: 'Antennen & Antennenhalterungen',
      langText: 'Prüfung',
    )
      ..id = '123-7-null-null'
      ..author = 'tester';
    final remappedIds = <String>[];

    final merged = await API.mergeCachedAndUpstream<CheckCategory>(
      cached: [local],
      upstream: [remote],
      onIdRemapped: (cached, upstream) {
        remappedIds.add('${cached.id}->${upstream.id}');
      },
    );

    expect(merged, [remote]);
    expect(remappedIds, ['__loc__category->123-7-null-null']);
  });

  test('keeps an unrelated unsynced category visible', () async {
    final local = CheckCategory(
      pjNr: 123,
      index: -1,
      kurzText: 'Neue lokale Kategorie',
    )
      ..id = '__loc__category'
      ..forceOffline = true;
    final remote = CheckCategory(
      pjNr: 123,
      index: 7,
      kurzText: 'Andere Kategorie',
    )..id = '123-7-null-null';

    final merged = await API.mergeCachedAndUpstream<CheckCategory>(
      cached: [local],
      upstream: [remote],
    );

    expect(merged, [remote, local]);
  });
}
