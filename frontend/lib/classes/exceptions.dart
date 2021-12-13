import 'dart:convert';

import 'package:http/http.dart' as http;

class NoConnectionToBackendException extends BackendCommunicationException {
  @override
  String toString() {
    return cause ?? 'NoConnectionToBackendException';
  }

  NoConnectionToBackendException(String? cause) : super(cause);
}

class ResponseException implements Exception {
  http.Response? res;
  @override
  String toString() {
    String error = '';
    if (res != null) {
      try {
        error = jsonDecode(res!.body)['error'];
      } catch (e) {
        'the body had no error field';
      }
      return '${res?.statusCode}: ${error}';
    }
    return 'no response';
  }

  ResponseException(this.res);
}

class LoginException implements Exception {}

class BackendCommunicationException implements Exception {
  String? cause;
  @override
  String toString() {
    return cause ?? 'Something went wrong while communicating with the API';
  }

  BackendCommunicationException(this.cause);
}
