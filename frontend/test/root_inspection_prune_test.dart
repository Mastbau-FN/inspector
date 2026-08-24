import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects stale local inspections missing from the server snapshot', () {
    final kept = _inspection(id: 'server-kept', pjNr: 1);
    final deleted = _inspection(id: 'server-deleted', pjNr: 2);

    final stale = API.staleLocalRootInspections(
      local: [kept, deleted],
      remote: [_inspection(id: 'server-kept', pjNr: 1)],
    );

    expect(stale, [deleted]);
  });

  test('keeps locally offline inspections during server pruning', () {
    final offline = _inspection(id: 'local-offline', pjNr: 3)
      ..forceOffline = true;

    final stale = API.staleLocalRootInspections(
      local: [offline],
      remote: const [],
    );

    expect(stale, isEmpty);
  });

  test('treats changed server ids as stale local cache entries', () {
    final oldLocal = _inspection(id: 'old-local-id', pjNr: 4, stONr: 7);
    final refreshed = _inspection(id: 'new-server-id', pjNr: 4, stONr: 7);

    final stale = API.staleLocalRootInspections(
      local: [oldLocal],
      remote: [refreshed],
    );

    expect(stale, [oldLocal]);
  });

  test('keeps an explicit offline selection on refreshed server data', () {
    final cachedOffline = _inspection(id: 'same-id', pjNr: 5)
      ..forceOffline = true;
    final cachedOnline = _inspection(id: 'online-id', pjNr: 6);
    final refreshedOffline = _inspection(id: 'same-id', pjNr: 5);
    final refreshedOnline = _inspection(id: 'online-id', pjNr: 6);

    API.preserveOfflineSelectionsFromCache(
      cached: [cachedOffline, cachedOnline],
      upstream: [refreshedOffline, refreshedOnline],
    );

    expect(refreshedOffline.forceOffline, isTrue);
    expect(refreshedOnline.forceOffline, isFalse);
  });
}

InspectionLocation _inspection({
  required String id,
  required int pjNr,
  int stONr = 1,
}) {
  final inspection = InspectionLocation(pjNr: pjNr, stONr: stONr);
  inspection.id = id;
  return inspection;
}
