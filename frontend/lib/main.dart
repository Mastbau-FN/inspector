import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:MBG_Inspektionen/pages/login/loginView.dart';
import 'package:MBG_Inspektionen/theme.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';

Future main() async {
  //TODO: the .env is stored as plaintext file (for web at least) thats super no good (e.g. for storing API-KEY) so TODO: obfuscate .env storage (have a look at freerasp plugin)
  // could be done via --dart-define=API_KEY=SOME_VALUE flutter cli arg

  await dotenv.load(fileName: ".env");
  runApp(GlobalProviders(child: MyApp()));
}

/// how the App is called (shown in AppBar or Tab etc.)
const String appTitle = 'MBG Inspektionen';

/**
 * Main App entry point
 */
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: mbgpalette0,
      ),
      home: kIsWeb
          ? WebWrap(
              title: appTitle,
            )
          : LoginWrapper(title: appTitle),
    );
  }
}

class WebWrap extends StatelessWidget {
  final bool webSupported = true;
  final String title;
  const WebWrap({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return webSupported
        ? LoginWrapper(title: title)
        : Container(
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
              ),
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ErrorText(
                      'the web is currently not supported, but it will be soon',
                      color: Colors.yellow[800]!,
                    ),
                    Text('a link to the built APK will also follow soon')
                  ],
                ),
              ),
            ),
          );
  }
}
