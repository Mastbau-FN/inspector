import 'package:camera/camera.dart';
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

  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

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
        colorScheme: ColorScheme.fromSwatch(primarySwatch: mbgpalette0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch:
              mbgpalette0, //if someone wonders why this doesnt work, it might be with a future flutter upgrade (https://github.com/flutter/flutter/issues/19089)
          brightness: Brightness.dark,
        ),
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
