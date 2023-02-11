import 'package:flutter/material.dart';
import 'package:MBG_Inspektionen/classes/user.dart';
import 'package:MBG_Inspektionen/fragments/ErrorView.dart';
import 'package:MBG_Inspektionen/pages/homeView.dart';
import 'package:MBG_Inspektionen/fragments/loadingscreen/loadingView.dart';
import 'package:MBG_Inspektionen/pages/location.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import 'package:MBG_Inspektionen/l10n/locales.dart';
import 'loginModel.dart';
import 'package:MBG_Inspektionen/widgets/error.dart';

/// Wraps the whole app to provide login if no user is signed in, and provide the credentials for use by children
///
/// {@category Login}
class GlobalProviders extends StatelessWidget {
  final Widget child;
  const GlobalProviders({required this.child, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (c) => LoginModel(),
        ),
        /*ChangeNotifierProvider(
            create: (c) => CategoryModel(),
          ),*/
      ],
      child: child,
    );
  }
}

/// {@category Login}
/// If no user is logged in (given by [LoginModel]) it shows the [LoginView].
/// If someone is already logged in it directly forwards to the [HomeView]
class LoginWrapper extends StatelessWidget {
  const LoginWrapper({
    Key? key,
    required this.title,
  }) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Consumer<LoginModel>(
      builder: (context, login, child) {
        debugPrint("login changed");
        return FutureBuilder<DisplayUser?>(
            future: login.user,
            builder: (context, snapshot) {
              return ChangeNotifierProvider(
                create: (c) => LocationModel(user: snapshot.data),
                child: FutureBuilder(
                    future: login.isLoggedIn,
                    builder: (context, AsyncSnapshot<bool> snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        if (snapshot.hasError) return ErrorView(snapshot.error);
                        return snapshot.data ?? false
                            ? HomeView(
                                title: title,
                              )
                            : LoginView(title: title);
                      }
                      return LoadingPage();
                    }),
              );
            });
      },
    );
  }
}

/// {@category Login}
/// The Login View with username and password field
class LoginView extends StatelessWidget {
  final String title;
  const LoginView({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'lib/assets/icon_smooth.svg',
              semanticsLabel: 'MBG Logo',
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: 20),
            LoginField(
              padding: EdgeInsets.all(10),
            ),
          ],
        )),
      ),
    );
  }
}

/// Plain LoginField.
/// uses the [LoginModel] to log a user in
class LoginField extends StatefulWidget {
  final bool autofocus;
  final EdgeInsets padding;

  LoginField(
      {this.padding = const EdgeInsets.all(5),
      Key? key,
      this.autofocus = false})
      : super(key: key);

  @override
  _LoginFieldState createState() => _LoginFieldState();
}

class _LoginFieldState extends State<LoginField> {
  static const double padding = 10;

  final _formKey = GlobalKey<FormState>();

  String? username;

  String? password;

  String? errorMessage;

  bool loading = false;

  Future logmein(BuildContext context) async {
    setState(() {
      errorMessage = null;
    });
    if (_formKey.currentState!.validate()) {
      final controller = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.of(context).loginCredentialsAreBeeingVerified)),
      );
      try {
        _formKey.currentState!.save();
        setState(() {
          loading = true;
        });
        await Provider.of<LoginModel>(context, listen: false)
            .login(username, password);

        controller.close();
        setState(() {
          errorMessage = null;
          loading = false;
        });
      } catch (e) {
        try {
          controller.close();
        } catch (e) {
          //'the controller was already closed';
        }
        setState(() {
          errorMessage = e.toString();
          loading = false;
        });
      }
    }
  }

  InputDecoration fieldDecoration(BuildContext context,
          {required String name}) =>
      InputDecoration(
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50.0),
          borderSide: BorderSide(
            //XXX: should be .outline (as it is per default), but isnt liked by uwe
            color: Theme.of(context).colorScheme.scrim.withAlpha(50),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.tertiary,
            width: 2,
          ),
        ),
        // border: OutlineInputBorder(),
        labelText: name,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
            duration: Duration(milliseconds: 400),
            height: loading ? 70 + padding : 0,
            width: loading ? 70 : 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: padding),
              child: LoadingView(),
            )),
        AnimatedContainer(
          duration: Duration(milliseconds: 400),
          height: errorMessage != null ? 70 + padding : 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: padding),
            child: AnimatedOpacity(
                opacity: errorMessage != null ? 1 : 0,
                duration: Duration(milliseconds: 400),
                child: ErrorText(errorMessage)),
          ),
        ),
        Container(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: widget.padding,
                  child: TextFormField(
                    onSaved: (value) {
                      username = value;
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return S.of(context).loginErrorPleaseEnterUserName;
                      }
                      return null;
                    },
                    autofocus: widget.autofocus,
                    decoration: fieldDecoration(context,
                        name: S.of(context).loginUsername),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                Padding(
                  padding: widget.padding,
                  child: TextFormField(
                    onSaved: (value) {
                      password = value;
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return S.of(context).loginErrorPleaseEnterPassword;
                      }
                      return null;
                    },
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: fieldDecoration(context,
                        name: S.of(context).loginLabelPassword),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => logmein(context),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    logmein(context);
                  },
                  child: Text(S.of(context).loginButton),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
