import 'package:flutter/material.dart';
import 'package:mastbau_inspector/pages/login/loginModel.dart';
import 'package:provider/provider.dart';

/// a page where the user can change settings. it currently support [Logout]
class SettingsView extends StatelessWidget {
  final BuildContext logoutcontext;
  const SettingsView({Key? key, required this.logoutcontext}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Logout(
            logoutcontext: logoutcontext,
          )
        ],
      ),
    );
  }
}

class Logout extends StatelessWidget {
  final BuildContext logoutcontext;
  const Logout({Key? key, required this.logoutcontext}) : super(key: key);

  /// logs the user out and resets app state accordingly
  Future _logout(context) async {
    /*Navigator.popUntil(
        context,
        /*MaterialPageRoute(
      builder: (context) {
        Provider.of<LoginModel>(context, listen: false).logout();
        return LoginWrapper('mastbau');
      },
    ),*/
        (route) => route.isFirst);*/
    await Provider.of<LoginModel>(context, listen: false).logout();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
        onPressed: () async {
          ////Phoenix.rebirth(context);
          await _logout(context);
        },
        child: Text("Logout"));
  }
}
