import 'dart:io';

import 'package:MBG_Inspektionen/backend/api.dart';
import 'package:MBG_Inspektionen/backend/backend_reachability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    BackendReachability.instance.resetForTest();
  });

  test('throttles repeated failed host lookup logs without blocking retries',
      () {
    final reachability = BackendReachability.instance;
    final error =
        SocketException("Failed host lookup: 'inspection.mbg-solutions.com'");

    expect(reachability.markFailure(error), isTrue);
    expect(reachability.lastFailureMessage, contains('Failed host lookup'));

    expect(reachability.markFailure(error), isFalse);
    expect(reachability.lastFailureMessage, contains('Failed host lookup'));
  });

  test('ignores unrelated request errors', () {
    final reachability = BackendReachability.instance;

    expect(reachability.markFailure(Exception('HTTP 500')), isFalse);
    expect(reachability.lastFailureMessage, isNull);
  });

  test('does not force online retry for offline or cache-preferred data', () {
    expect(
      API.shouldForceOnlineAfterOfflineMiss(
        onlineSucceeded: false,
        offlineSucceeded: false,
        prefersCache: true,
        forceOffline: false,
      ),
      isFalse,
    );

    expect(
      API.shouldForceOnlineAfterOfflineMiss(
        onlineSucceeded: false,
        offlineSucceeded: false,
        prefersCache: false,
        forceOffline: true,
      ),
      isFalse,
    );
  });

  test('keeps online retry for normal cache misses', () {
    expect(
      API.shouldForceOnlineAfterOfflineMiss(
        onlineSucceeded: false,
        offlineSucceeded: false,
        prefersCache: false,
        forceOffline: false,
      ),
      isTrue,
    );
  });
}
