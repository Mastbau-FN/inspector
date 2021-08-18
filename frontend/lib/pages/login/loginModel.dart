import 'package:flutter/widgets.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/user.dart';

class LoginModel extends ChangeNotifier {
  LoginModel();

  /// whether anyone is logged in, used to switch whether to show the login screen or the main view
  Future<bool> get isLoggedIn async => await Backend().isAnyoneLoggedIn();

  /// logs the user in and updates the UI
  Future login(String? username, String? password) async {
    if (username == null || password == null) {
      throw Exception("username or password was not given");
    }

    var res = await Backend().login(User(username, password));
    print(res);
    notifyListeners();
  }

  /// logs the user out and therefor resets the UI to show the login-screen again
  Future logout() async {
    await Backend().logout();
    notifyListeners();
  }
}
