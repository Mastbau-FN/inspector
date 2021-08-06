import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tuple/tuple.dart';

class LoginModel extends ChangeNotifier {
  String? username;
  String? password;

  DotEnv dotenv;

  LoginModel(this.dotenv);

  bool get isLoggedIn => username != null && password != null;
  String get apikey =>
      dotenv.env['API_KEY']!; //throws error if api-key not given

  Future login(String? username, String? password) async {
    if (username == null || password == null) {
      throw Exception("username or password was not given");
    }
    // TODO query backend if this is a valid combo
    await Future.delayed(Duration(seconds: 2));

    notifyListeners();
    throw Exception("logging in not yet supported");
  }
}
