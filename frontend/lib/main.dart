import 'package:MBG_Inspektionen/notifications/controller.dart';
import 'package:MBG_Inspektionen/options.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/pages/login/loginView.dart';
import 'package:MBG_Inspektionen/theme.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'pages/defaultNotificationPage.dart';

Future main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  await Options().load();
  // await NewImages.load();

  NotificationController.initialize();

  runApp(GlobalProviders(child: MyApp()));
}

/// how the App is called (shown in AppBar or Tab etc.)
const String appTitle = 'MBG Inspektionen';

/// Main App entry point
class MyApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    NotificationController.initListeners();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        navigatorKey: MyApp.navigatorKey,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(
                builder: (context) => kIsWeb
                    ? WebWrap(
                        title: appTitle,
                      )
                    : LoginWrapper(title: appTitle),
              );
            case '/default-notification-page':
              return MaterialPageRoute(builder: (context) {
                final ReceivedAction receivedAction =
                    settings.arguments as ReceivedAction;
                return DefaultNotificationPage(action: receivedAction);
              });
            default:
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ErrorText('404, Route not found'),
                  ),
                ),
              );
          }
        },
      ),
    );
  }
}

class WebWrap extends StatelessWidget {
  final bool webSupported = true;
  final String title;
  const WebWrap({required this.title, Key? key}) : super(key: key);

  static const String apkUrl =
      'https://github.com/Mastbau-FN/inspector/releases/latest/download/inspector.apk';

  @override
  Widget build(BuildContext context) {
    var textButton = TextButton(
      onPressed: () async {
        if (await canLaunchUrl(Uri.parse(apkUrl))) {
          await launchUrl(Uri.parse(apkUrl));
        } else {
          throw 'Could not launch $apkUrl';
        }
      },
      child: Text(
        'download latest apk',
        style: TextStyle(color: Colors.green),
      ),
    );
    return webSupported
        ? Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: LoginWrapper(title: title),
              ),
              Container(
                height: 20,
                child: Scaffold(
                  body: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          "! the support for web is very limited, consider installing the apk:",
                          style: TextStyle(color: Colors.yellow[800])),
                      textButton,
                    ],
                  ),
                ),
              )
            ],
          )
        : Container(
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
              ),
              body: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ErrorText(
                      'the web is currently not supported, but it will be soon',
                      color: Colors.yellow[800]!,
                    ),
                    textButton,
                  ],
                ),
              ),
            ),
          );
  }
}
