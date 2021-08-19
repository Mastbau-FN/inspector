import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayUser {
  /// this is aquivalent to the KZL
  final String name;

  String? full_name;
  String? full_surname;

  DisplayUser(this.name, {this.full_name, this.full_surname});

  @override
  String toString() {
    return (full_name != null && full_surname != null)
        ? '${full_name?[0]}. $full_surname'
        : name;
  }

  void fromMap(Map<String, dynamic>? map) {
    full_surname = map?['Name'];
    full_name = map?['Vorname'];
  }
}

class User extends DisplayUser {
  final String pass;

  User(name, this.pass, {full_name, full_surname})
      : super(name, full_name: full_name, full_surname: full_surname);

  /*factory User.fromMap(Map<String, dynamic> map){
    return User(map['name'],map[''])
  }*/

  Map<String, dynamic> toJson() => {
        'name': name,
        'pass': pass,
      };

  // Create secure storage
  static final _storage = new FlutterSecureStorage();
  static const _username_store = "user_name";
  static const _userpass_store = "user_pass";

  // Insecure Key-Value pairs
  static final _prefs = SharedPreferences.getInstance();
  static const _full_name_store = "full_name";
  static const _full_surname_store = "full_surname";

  /// stores the current user to the device
  Future store() async {
    await _storage.write(key: _username_store, value: name);
    await _storage.write(key: _userpass_store, value: pass);

    (await _prefs).setString(_full_name_store, full_name ?? 'noname');
    (await _prefs).setString(_full_surname_store, full_surname ?? 'noname');
  }

  /// deletes user from device (used for logout)
  Future unstore() async {
    await _storage.write(key: _username_store, value: null);
    await _storage.write(key: _userpass_store, value: null);
  }

  /// creates a new User from variables stored on device
  static Future<User?> fromStore() async {
    String? name = await _storage.read(key: _username_store);
    String? pass = await _storage.read(key: _userpass_store);
    if (name == null || pass == null) return null;
    var _user = User(name, pass);
    _user.full_name = (await _prefs).getString(_full_name_store);
    _user.full_surname = (await _prefs).getString(_full_surname_store);
  }
}
