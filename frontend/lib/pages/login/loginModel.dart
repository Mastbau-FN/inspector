import 'package:flutter/widgets.dart';
import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/classes/user.dart';

class LoginModel extends ChangeNotifier {
  LoginModel();

  /// whether anyone is logged in, used to switch whether to show the login screen or the main view
  Future<bool> get isLoggedIn async => await Backend().isAnyoneLoggedIn;
  Future<DisplayUser?> get user async => await Backend().user;

  /// logs the user in and updates the UI
  Future login(String? username, String? password) async {
    // current kürzel and password for testing are HH testpass
    if (username == null || password == null) {
      throw Exception("username or password was not given");
    }

    var res = await Backend().login(User(username, password));
    debugPrint(res.toString());
    notifyListeners();
  }

  /// logs the user out and therefor resets the UI to show the login-screen again
  Future logout() async {
    await Backend().logout();
    notifyListeners();
  }
}
