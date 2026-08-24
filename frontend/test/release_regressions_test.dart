import 'dart:io';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/data/checkcategory.dart';
import 'package:MBG_Inspektionen/classes/dropdownClasses.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/pages/dropDownPageB.dart';
import 'package:MBG_Inspektionen/pages/location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OSM tile requests identify the app and do not use subdomains', () {
    expect(
        osmTileUrlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    expect(osmTileUrlTemplate, isNot(contains('{s}')));
    expect(osmUserAgentPackageName, 'com.mbgsolutions.inspector');
  });

  test('sharing resolves an uploaded hash through the local image index',
      () async {
    final calls = <String>[];
    final expected = File('/tmp/captured-image.jpg');

    final result = await resolveShareImageFile(
      'remote-hash',
      scope: 'inspection/category/checkpoint',
      fileResolver: (name, {scope}) async {
        calls.add('resolve:$scope:$name');
        return name == 'capture-123.jpg' ? expected : null;
      },
      nameLookup: (hash, {scope}) async {
        calls.add('lookup:$scope:$hash');
        return 'capture-123.jpg';
      },
    );

    expect(result, same(expected));
    expect(calls, [
      'resolve:inspection/category/checkpoint:remote-hash',
      'lookup:inspection/category/checkpoint:remote-hash',
      'resolve:inspection/category/checkpoint:capture-123.jpg',
    ]);
  });

  test('new online records receive the current KZL as author', () {
    final category = CheckCategory(pjNr: 123, index: -1)..id = 'category';

    assignAuthorForNewData(category, DisplayUser('TK'));

    expect(category.author, 'TK');
    expect(category.toJson()['Autor'], 'TK');
    expect(isOwnedByUser(category, DisplayUser(' tk ')), isTrue);
    expect(isOwnedByUser(category, DisplayUser('other')), isFalse);
  });

  test('author stamping never overwrites an existing author', () {
    final category = CheckCategory(pjNr: 123, index: -1)
      ..id = 'category'
      ..author = 'ORIGINAL';

    assignAuthorForNewData(category, DisplayUser('CURRENT'));

    expect(category.author, 'ORIGINAL');
  });
}
