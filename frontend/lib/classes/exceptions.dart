import 'dart:convert';

import 'package:http/http.dart' as http;

class NoConnectionToBackendException implements Exception {
  String? cause;
  NoConnectionToBackendException(this.cause);
}

class ResponseException implements Exception {
  http.Response res;
  @override
  String toString() {
    return '${res.statusCode}: ${jsonDecode(res.body)['error']}';
  }

  ResponseException(this.res);
}

class LoginException implements Exception {}
