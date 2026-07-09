import 'dart:io';

import 'package:flutter/foundation.dart';

class BackendReachability {
  BackendReachability._();

  static final BackendReachability instance = BackendReachability._();
  static const Duration defaultOfflineCooldown = Duration(seconds: 30);

  DateTime? _skipOnlineUntil;
  String? _lastFailureMessage;

  Duration? get remainingOfflineCooldown {
    final until = _skipOnlineUntil;
    if (until == null) return null;

    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      clearFailure();
      return null;
    }
    return remaining;
  }

  String? get lastFailureMessage => _lastFailureMessage;

  bool markFailure(
    Object error, {
    Duration cooldown = defaultOfflineCooldown,
  }) {
    if (!isBackendReachabilityFailure(error)) return false;

    final wasAlreadySkipping = remainingOfflineCooldown != null;
    _skipOnlineUntil = DateTime.now().add(cooldown);
    _lastFailureMessage = _messageFrom(error);
    return !wasAlreadySkipping;
  }

  void clearFailure() {
    _skipOnlineUntil = null;
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
