// ignore_for_file: non_constant_identifier_names

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// all userdata that is needed to use it in the UI
class DisplayUser {
  /// this is aquivalent to the KZL
  final String name;

  String? full_name;
  String? full_surname;
  int? defLoginId;

  DisplayUser(this.name, {this.full_name, this.full_surname, this.defLoginId});

  @override
  String toString() {
    return (full_name != null && full_surname != null)
        ? '${full_name?[0]}. $full_surname'
        : name;
  }

  void fromMap(Map<String, dynamic>? map) {
    full_surname = map?['Name'];
    full_name = map?['Vorname'];
    try {
      final v = map?['Def_Login_ID'] ??
          map?['def_login_id'] ??
          map?['Login_ID_Pruefer'] ??
          map?['login_id_pruefer'];
      if (v is int) defLoginId = v;
      if (v is num) defLoginId = v.toInt();
      if (v is String) defLoginId = int.tryParse(v);
    } catch (_) {}
  }
}

/// extends the [DisplayUser] by the [pass] field, which is used to store the password for the current user.
/// this should not be used in the UI, cause it risks exposing the password
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
  static const _def_login_id_store = "def_login_id";

  /// stores the current user to the device
  Future store() async {
    await _storage.write(key: _username_store, value: name);
    await _storage.write(key: _userpass_store, value: pass);

    (await _prefs).setString(_full_name_store, full_name ?? 'noname');
    (await _prefs).setString(_full_surname_store, full_surname ?? 'noname');
    final prefs = await _prefs;
    if (defLoginId != null) {
      await prefs.setInt(_def_login_id_store, defLoginId!);
    } else {
      await prefs.remove(_def_login_id_store);
    }
  }

  /// deletes user from device (used for logout)
  Future unstore() async {
    try {
      // Lösche Anmeldedaten
      await _storage.delete(key: _username_store);
      await _storage.delete(key: _userpass_store);

      // Lösche auch die nicht-sensiblen Daten
      final prefs = await _prefs;
      await prefs.remove(_full_name_store);
      await prefs.remove(_full_surname_store);
      await prefs.remove(_def_login_id_store);

      debugPrint('User-Daten vollständig gelöscht');
    } catch (e) {
      debugPrint('Fehler beim Löschen der Benutzerdaten: $e');
    }
  }

  /// creates a new User from variables stored on device
  static Future<User?> fromStore() async {
    String? name = await _storage.read(key: _username_store);
    String? pass = await _storage.read(key: _userpass_store);
    if (name == null || pass == null) return null;
    var _user = User(name, pass);
    _user.full_name = (await _prefs).getString(_full_name_store);
    _user.full_surname = (await _prefs).getString(_full_surname_store);
    _user.defLoginId = (await _prefs).getInt(_def_login_id_store);
    return _user;
  }
}
