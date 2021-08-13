// TODO

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mastbau_inspector/assets/consts.dart';
import '/classes/exceptions.dart';
import '/classes/user.dart';

/// backend Singleton to provide all functionality related to the backend
class Backend {
  static final Backend _instance = Backend._internal();
  factory Backend() => _instance;

  // Create secure storage
  final _storage = new FlutterSecureStorage();
  static const _username_store = "user_name";
  static const _userpass_store = "user_pass";

  final _baseurl = dotenv.env['API_URL'];
  final _api_key = dotenv.env['API_KEY'] ?? "apitestkey";

  User? _user;

  /// returns the currently logged in [User], whether its already initialized or not.
  /// should be prefered over [_user], since it makes sure to have it initialized
  Future<User?> _c_user() async {
    if (_user != null) return _user;
    String? name = await _storage.read(key: _username_store);
    String? pass = await _storage.read(key: _userpass_store);
    if (name == null || pass == null) return null;
    _user = User(name, pass);
    return _user;
  }

  Backend._internal() {
    // init
  }

  /// checks whether a connection to the backend is possible
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future connectionGuard() async {
    if (_baseurl == null)
      throw NoConnectionToBackendException("no url provided");

    //check network
    var connection = await (Connectivity().checkConnectivity());
    if (connection == ConnectivityResult.none)
      throw NoConnectionToBackendException("no network available");
    if (!canUseMobileNetworkIfPossible &&
        connection == ConnectivityResult.mobile)
      throw NoConnectionToBackendException("mobile network not allowed");

    try {
      // check if we can reach our api
      await post_JSON('/login');
    } catch (e) {
      throw NoConnectionToBackendException("couldn't reach $_baseurl");
    }
  }

  /// checks whether the given user is currently logged in
  Future<bool> isUserLoggedIn(User user) async => user == await _c_user();

  /// checks whether anyone is currently logged in
  Future<bool> isAnyoneLoggedIn() async => await _c_user() != null;

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  Future<http.Response> post(String route,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    headers = headers ?? {};
    headers.addAll({HttpHeaders.authorizationHeader: _api_key});
    var fullURL = Uri.parse(_baseurl! + route);
    print(fullURL);
    return http.post(fullURL, headers: headers, body: body, encoding: encoding);
  }

  //TODO: needs testing
  /// post_JSON to our backend as the user
  Future<http.Response> post_JSON(String route,
      {Map<String, dynamic>? json}) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    json = json ?? {};
    json['user'] = await _c_user();
    return post(route, headers: headers, body: jsonEncode(json));
  }

  /// login a [User] by checking if he exists in the remote database
  Future<Map<String, dynamic>?> login(User user) async {
    // if user is already logged in
    if (await isUserLoggedIn(user)) return {'alreadyLoggedIn': true};
    await connectionGuard();
    _user = user;
    var res = await post_JSON('/login');
    if (res.statusCode == 200) {
      //success
      await _storage.write(key: _username_store, value: user.name);
      await _storage.write(key: _userpass_store, value: user.pass);
      return jsonDecode(res.body);
    }

    // login failed
    _user = null;

    // logout user
    await _storage.write(key: _username_store, value: null);
    await _storage.write(key: _userpass_store, value: null);
    throw ResponseException(res);
  }
}
