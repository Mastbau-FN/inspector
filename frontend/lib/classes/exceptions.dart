import 'dart:convert';

import 'package:http/http.dart' as http;

class NoConnectionToBackendException implements Exception {
  String? cause;
  @override
  String toString() {
    return cause ?? 'NoConnectionToBackendException';
  }

  NoConnectionToBackendException(this.cause);
}

class ResponseException implements Exception {
  http.Response res;
  @override
  String toString() {
    String error = '';
    try {
      error = jsonDecode(res.body)['error'];
    } catch (e) {
      'the body had no error field';
    }
    return '${res.statusCode}: ${error}';
  }

  ResponseException(this.res);
}

class LoginException implements Exception {}
