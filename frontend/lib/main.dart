import 'package:MBG_Inspektionen/options.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/login/loginView.dart';
import 'package:MBG_Inspektionen/theme.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';

import 'generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  await Options().load();
  // await NewImages.load();

  runApp(GlobalProviders(child: MyApp()));
}

/// how the App is called (shown in AppBar or Tab etc.)
const String appTitle = 'MBG Inspektionen';

/// Main App entry point
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: appTitle,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: (Options().useSystemTheme ? lightDynamic : null) ??
              ColorScheme.fromSwatch(
                  primarySwatch: mbgpalette0, backgroundColor: Colors.white),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: (Options().useSystemTheme ? darkDynamic : null) ??
              ColorScheme.fromSwatch(
                primarySwatch:
                    mbgpalette0, //if someone wonders why this doesnt work, it might be with a future flutter upgrade (https://github.com/flutter/flutter/issues/19089)
                brightness: Brightness.dark,
                backgroundColor: Colors.black,
                cardColor: Colors.grey[900],
              ),
          appBarTheme: AppBarTheme(
            color: Colors.black,
          ),
          brightness: Brightness.dark,
        ),
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          S.delegate,
        ],
        supportedLocales: S.delegate.supportedLocales,
        home: kIsWeb
            ? WebWrap(
                title: appTitle,
              )
            : LoginWrapper(title: appTitle),
      ),
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
