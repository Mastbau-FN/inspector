// TODO

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mastbau_inspector/classes/user.dart';

class NoConnectionToBackendException implements Exception {
  String? cause;
  NoConnectionToBackendException(this.cause);
}

class Backend {
  static final Backend _instance = Backend._internal();
  factory Backend() => _instance;

  // Create storage
  final _storage = new FlutterSecureStorage();
  final _baseurl = dotenv.env['API_URL'];
  final _api_key = dotenv.env['API_KEY'] ?? "apitestkey";

  User? user;

  Backend._internal() {
    // init
  }

  /// checks whether a connection to the backend is possible
  /// throws [NoConnectionToBackendException] or [SocketException] if its not.
  Future connectionGuard() async {
    if (_baseurl == null)
      throw NoConnectionToBackendException("no url provided");
    final result = await InternetAddress.lookup(_baseurl!);
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return;
    }
    throw NoConnectionToBackendException("couldn't find $_baseurl");
  }

  /// checks whether the given user is currently logged in
  Future isLoggedIn(User user) async {
    return (user.name == await _storage.read(key: "username") &&
        user.pass == await _storage.read(key: "userpass"));
  }

  /// make an actual API request to a route, and always append the API_KEY as authorization-header
  Future<http.Response> post(String route,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    headers = headers ?? {};
    headers.addAll({HttpHeaders.authorizationHeader: _api_key});
    return http.post(Uri.parse(_baseurl! + route),
        headers: headers, body: body, encoding: encoding);
  }

  //TODO: needs testing
  /// post_JSON to our backend as the user
  Future<http.Response> post_JSON(
      String route, Map<String, dynamic> json) async {
    var headers = {HttpHeaders.contentTypeHeader: 'application/json'};
    json['user'] = user;
    return post(route, headers: headers, body: jsonEncode(json));
  }

  /// login a user by checking if he exists in the remote database
  Future login(User user) async {
    // if user is already logged in
    if (await isLoggedIn(user)) return;
    await connectionGuard();
    var res = await post(
      '/login',
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      body: jsonEncode(user),
    );

    return false;
  }
}
