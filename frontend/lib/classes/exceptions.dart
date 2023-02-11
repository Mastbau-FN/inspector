import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:MBG_Inspektionen/l10n/locales.dart';

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
        S.current!.theBodyHadNoErrorField;
      }
      return '${res?.statusCode}: $error';
    }
    return S.current!.noResponse;
  }

  ResponseException(this.res);
}

class LoginException implements Exception {}

class BackendCommunicationException implements Exception {
  String? cause;
  @override
  String toString() {
    return cause ?? S.current!.somethingWentWrongWhileCommunicatingWithTheApi;
  }

  BackendCommunicationException(this.cause);
}
