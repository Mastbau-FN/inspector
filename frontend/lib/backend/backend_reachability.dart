import 'dart:io';

import 'package:flutter/foundation.dart';

class BackendReachability {
  BackendReachability._();

  static final BackendReachability instance = BackendReachability._();
  static const Duration defaultFailureLogThrottle = Duration(seconds: 30);

  DateTime? _lastFailureLoggedAt;
  String? _lastFailureMessage;

  String? get lastFailureMessage => _lastFailureMessage;

  bool markFailure(
    Object error, {
    Duration logThrottle = defaultFailureLogThrottle,
  }) {
    if (!isBackendReachabilityFailure(error)) return false;

    final message = _messageFrom(error);
    final now = DateTime.now();
    final shouldLog = _lastFailureLoggedAt == null ||
        _lastFailureMessage != message ||
        now.difference(_lastFailureLoggedAt!) >= logThrottle;
    _lastFailureLoggedAt = shouldLog ? now : _lastFailureLoggedAt;
    _lastFailureMessage = message;
    return shouldLog;
  }

  void clearFailure() {
    _lastFailureLoggedAt = null;
    _lastFailureMessage = null;
  }

  @visibleForTesting
  void resetForTest() => clearFailure();

  static bool isBackendReachabilityFailure(Object error) {
    final message = _messageFrom(error).toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('no address associated with hostname') ||
        message.contains('network is unreachable');
  }

  static String _messageFrom(Object error) {
    if (error is SocketException) return error.message;
    return error.toString();
  }
}
