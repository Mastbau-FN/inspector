import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:mastbau_inspector/classes/user.dart';
import 'package:mastbau_inspector/fragments/ErrorView.dart';
import 'package:mastbau_inspector/pages/home/homeView.dart';
import 'package:mastbau_inspector/pages/loadingscreen/loadingView.dart';
import 'package:mastbau_inspector/pages/locationOverview/locationModel.dart';
import 'package:provider/provider.dart';

import 'loginModel.dart';
import 'package:mastbau_inspector/widgets/error.dart';

/// Wraps the whole app to provide login if no user is signed in, and provide the credentials for use by children
///
/// {@category Login}
/// If no user is logged in (given by [LoginModel]) it shows the [LoginView].
/// If someone is already logged in it directly forwards to the [HomeView]
class LoginWrapper extends StatelessWidget {
  final String title;
  const LoginWrapper(this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Phoenix(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (c) => LoginModel(),
          ),
          /*ChangeNotifierProvider(
            create: (c) => CategoryModel(),
          ),*/
        ],
        child: Consumer<LoginModel>(
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
                          if (snapshot.connectionState ==
                              ConnectionState.done) {
                            if (snapshot.hasError)
                              return ErrorView(snapshot.error);
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
        ),
      ),
    );
  }
}

/// {@category Login}
/// The Login View with username and password field
class LoginView extends StatelessWidget {
  String title;
  LoginView({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
            child: LoginField(
          padding: EdgeInsets.all(10),
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

  String? error_message;

  bool loading = false;

  Future logmein(BuildContext context) async {
    setState(() {
      error_message = null;
    });
    if (_formKey.currentState!.validate()) {
      final controller = ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daten werden überprüft..')),
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
          error_message = null;
          loading = false;
        });
      } catch (e) {
        try {
          controller.close();
        } catch (e) {
          'the controller was already closed';
        }
        setState(() {
          error_message = e.toString();
          loading = false;
        });
      }
    }
  }

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
              child: CircularProgressIndicator(),
            )),
        AnimatedContainer(
          duration: Duration(milliseconds: 400),
          height: error_message != null ? 70 + padding : 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: padding),
            child: AnimatedOpacity(
                opacity: error_message != null ? 1 : 0,
                duration: Duration(milliseconds: 400),
                child: ErrorText(error_message)),
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
                        return 'Bitte Kürzel eingeben';
                      }
                      return null;
                    },
                    autofocus: widget.autofocus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Kürzel',
                    ),
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
                        return 'Bitte Passwort eingeben';
                      }
                      return null;
                    },
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Passwort',
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => logmein(context),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    logmein(context);
                  },
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
