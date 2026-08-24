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

/// A queued multipart upload cannot be reconstructed because its local file
/// is missing, empty or unreadable. Retrying cannot repair this condition.
class MultipartFileUnavailableException implements Exception {
  final String path;
  final String reason;
  final List<String> candidates;

  const MultipartFileUnavailableException(
    this.path, {
    required this.reason,
    this.candidates = const [],
  });

  @override
  String toString() =>
      'MultipartFileUnavailableException(path: $path, reason: $reason)';
}

/// A backend image hash resolves to operating-system metadata instead of a
/// user image. This is a permanent server-data artifact, not a retryable
/// download failure.
class InvalidServerImageArtifactException implements Exception {
  final String hash;
  final String filename;

  const InvalidServerImageArtifactException({
    required this.hash,
    required this.filename,
  });

  @override
  String toString() =>
      'InvalidServerImageArtifactException(hash: $hash, filename: $filename)';
}

class BackendCommunicationException implements Exception {
  String? cause;
  @override
  String toString() {
    return cause ?? S.current!.somethingWentWrongWhileCommunicatingWithTheApi;
  }

  BackendCommunicationException(this.cause);
}
