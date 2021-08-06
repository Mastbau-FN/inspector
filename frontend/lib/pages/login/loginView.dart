import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mastbau_inspector/pages/home/homeView.dart';
import 'package:provider/provider.dart';

import 'loginModel.dart';
import 'package:mastbau_inspector/widgets/error.dart';

/// Wraps the whole app to provide login if no user is signed in, and provide the credentials for use by children
///
/// {@category Login}
/// receives a [DotEnv] to provide environment variables like the `API_KEY`.
/// If no user is logged in (given by [LoginModel]) it shows the [LoginView].
/// If someone is already logged in it directly forwards to the [HomeView]
class LoginWrapper extends StatelessWidget {
  final String title;
  const LoginWrapper(DotEnv dotenv, this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginModel(dotenv),
      child: Consumer<LoginModel>(
        builder: (context, login, child) {
          return login.isLoggedIn
              ? HomeView(
                  title: title,
                )
              : LoginView(title: title);
        },
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
        controller.close();
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
                        return 'Bitte Namen eingeben';
                      }
                      return null;
                    },
                    autofocus: widget.autofocus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Username',
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
                      labelText: 'Password',
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
