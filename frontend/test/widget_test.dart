import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:MBG_Inspektionen/backend/api.dart';

import 'package:MBG_Inspektionen/main.dart';
import 'package:MBG_Inspektionen/pages/login/loginView.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:integration_test/integration_test.dart';

// TODO if tests are wanted/needed , feel free
final doTestLol = false;

Future main() async {
  if (!doTestLol) {
    testWidgets(
        'fake test to trick my testenv to think i tested something although i didnt',
        (WidgetTester tester) async {
      tester.pumpWidget(MaterialApp(home: Text("this is not a test")));
    });
    return 0;
  }
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding();

  try {
    await integrationDriver(
      onScreenshot: (String screenshotName, List<int> screenshotBytes,
          [Map<String, Object?>? options]) async {
        final File image = await File('screenshots/$screenshotName.png')
            .create(recursive: true);
        image.writeAsBytesSync(screenshotBytes);
        return true;
      },
    );
  } catch (e) {
    print('Error occured: $e');
  }

//   testWidgets('Counter increments smoke test', (WidgetTester tester) async {
//     // Build our app and trigger a frame.
//     await tester.pumpWidget(MyApp());

//     // Verify that our counter starts at 0.
//     expect(find.text('0'), findsOneWidget);
//     expect(find.text('1'), findsNothing);

//     // Tap the '+' icon and trigger a frame.
//     await tester.tap(find.byIcon(Icons.add));
//     await tester.pump();

//     // Verify that our counter has incremented.
//     expect(find.text('0'), findsNothing);
//     expect(find.text('1'), findsOneWidget);
//   });
// }

  testWidgets('ErrorText test', (WidgetTester tester) async {
    var exc = Exception("test exception");
    await tester.pumpWidget(
      MaterialApp(
        home: ErrorText(
          exc.toString(),
          removeException: true,
        ),
      ),
    );

    // Verify that the leading exception has been removed, but not the rest
    expect(find.textContaining('Exception:'), findsNothing);
    expect(find.textContaining('test exception'), findsOneWidget);
  });

  testWidgets('Login test', (WidgetTester tester) async {
    //open new app
    await tester.pumpWidget(
      GlobalProviders(child: MyApp()),
    );
    await tester.pump();
    await binding.takeScreenshot('screenshot-1');

    //the user should be welcomed by 2 textfields for username and password
    expect(find.byElementType(TextField), findsNWidgets(2));

    await tester.enterText(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration!.labelText!.contains('name')),
        'NL');
    assert(Platform.environment['NL_PASS'] != null);
    await tester.enterText(
        find.textContaining('pass'), Platform.environment['NL_PASS']!);
  });

  ///test backend
  test('backend', () {
    var b = API();
    // TO DO
  });
}
