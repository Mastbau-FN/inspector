import 'package:flutter/widgets.dart';
import 'package:mastbau_inspector/backend/api.dart';
import 'package:mastbau_inspector/classes/user.dart';

class LoginModel extends ChangeNotifier {
  LoginModel();

  Future<bool> get isLoggedIn async => await Backend().isAnyoneLoggedIn();

  Future login(String? username, String? password) async {
    if (username == null || password == null) {
      throw Exception("username or password was not given");
    }

    var res = await Backend().login(User(username, password));
    print(res);
    notifyListeners();
  }
}
