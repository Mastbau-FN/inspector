import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/failedRequestManager.dart';
import 'package:MBG_Inspektionen/classes/data/inspection_location.dart';
import 'package:MBG_Inspektionen/classes/documentData.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses refreshed inspection metadata including documents', () {
    final current = _inspection(id: 'local-old');
    final refreshed = _inspection(
      id: 'local-old',
      documents: [
        DocumentData(filename: 'Plan.pdf', docupath: '/docs/plan.pdf'),
      ],
    );

    final selected = selectRefreshedInspectionForDownload(
      current,
      [refreshed],
    );

    expect(selected, same(refreshed));
    expect(selected!.dokuspaths, hasLength(1));
    expect(selected.dokuspaths!.single.filename, 'Plan.pdf');
  });

  test('falls back to project and location number when local ids changed', () {
    final current = _inspection(id: 'old-id');
    final refreshed = _inspection(
      id: 'new-id',
      documents: [
        DocumentData(filename: 'Statik.pdf', docupath: '/docs/statik.pdf'),
      ],
    );

    final selected = selectRefreshedInspectionForDownload(
      current,
      [_inspection(id: 'other-id', pjNr: 999), refreshed],
    );

    expect(selected, same(refreshed));
  });

  test('uses the same canonical document scope as the downloader', () {
    final inspection = _inspection(id: 'server-local-id');

    expect(
      API().local.scopeFor(inspection),
      '123-undefined-undefined-undefined',
    );
  });
}

InspectionLocation _inspection({
  required String id,
  int pjNr = 123,
  List<DocumentData>? documents,
}) {
  final inspection = InspectionLocation(
    pjNr: pjNr,
    stONr: 7,
    dokuspaths: documents,
  );
  inspection.id = id;
  return inspection;
}
