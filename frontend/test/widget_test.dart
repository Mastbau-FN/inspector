// TODO if tests are wanted/needed , feel free
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:mastbau_inspector/main.dart';
import 'package:mastbau_inspector/widgets/error.dart';

Future main() async {
  //load dotenv file (uses rootBundle, which inturn needs to be initialized)
  TestWidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
      MyApp(),
    );
    await tester.pump();

    //the user should be welcomed by 2 textfields for username and password
    //expect(find.byElementType(TextField), findsNWidgets(2));

    // await tester.enterText(
    //     find.byWidgetPredicate((widget) =>
    //         widget is TextField &&
    //         widget.decoration!.labelText!.contains('name')),
    //     'testuser');
    // await tester.enterText(find.textContaining('pass'), 'testpassword');
  });
}
