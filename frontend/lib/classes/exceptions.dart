import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        AppLocalizations.of(context)!.theBodyHadNoErrorField;
      }
      return '${res?.statusCode}: $error';
    }
    return AppLocalizations.of(context)!.noResponse;
  }

  ResponseException(this.res);
}

class LoginException implements Exception {}

class BackendCommunicationException implements Exception {
  String? cause;
  @override
  String toString() {
    return cause ??
        AppLocalizations.of(context)!
            .somethingWentWrongWhileCommunicatingWithTheApi;
  }

  BackendCommunicationException(this.cause);
}
