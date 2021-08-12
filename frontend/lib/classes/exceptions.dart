import 'package:http/http.dart' as http;

class NoConnectionToBackendException implements Exception {
  String? cause;
  NoConnectionToBackendException(this.cause);
}

class ResponseException implements Exception {
  http.Response res;
  @override
  String toString() {
    return 'Connection Failed, server responded with code \n ${res.statusCode} \n\n ${res.body}';
  }

  ResponseException(this.res);
}

class LoginException implements Exception {}
